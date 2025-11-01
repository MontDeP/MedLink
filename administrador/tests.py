# administrador/tests.py

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.conf import settings
from unittest.mock import patch # Para simular o envio de email

# Importa modelos e classes que o admin gere
from .models import LogEntry
from pacientes.models import Paciente
from medicos.models import Medico
from secretarias.models import Secretaria
from clinicas.models import Clinica, Cidade, Estado, TipoClinica # Para criar perfis


# Pega o modelo de User customizado
User = get_user_model()


# --- CLASSE BASE PARA SETUP DE DADOS E PERMISSÕES ---
class AdminBaseAPITestCase(APITestCase):
    """
    Configura utilizadores com diferentes papéis e dados auxiliares.
    """
    def setUp(self):
        # 1. ADMIN (Acesso Total) - Superuser
        self.user_admin = User.objects.create_superuser(
            cpf='99999999999', 
            email='admin@medlink.com', 
            password='adminpassword',
            first_name='Super',
            last_name='Admin',
        )

        # 2. NÃO-ADMIN (Acesso Proibido)
        self.user_medico = User.objects.create_user(
            cpf='11111111111', 
            email='medico@medlink.com', 
            password='userpassword',
            first_name='Dr.', 
            last_name='User', 
            user_type='MEDICO'
        )

        # 3. Utilizador Alvo (Será editado/deletado)
        self.user_alvo = User.objects.create_user(
            cpf='22222222222', 
            email='alvo@medlink.com', 
            password='alvopassword',
            first_name='Usuario', 
            last_name='Alvo', 
            user_type='PACIENTE'
        )
        
        # 4. Dados Auxiliares (Para criar perfis Medico/Secretaria)
        estado = Estado.objects.create(nome="Tocantins", uf="TO")
        cidade = Cidade.objects.create(nome="Palmas", estado=estado)
        tipo_clinica = TipoClinica.objects.create(descricao="Geral")
        self.clinica = Clinica.objects.create(
            nome_fantasia="Clínica Central", cidade=cidade, tipo_clinica=tipo_clinica, cnpj="11222333000144"
        )
        
        # 5. URLs (Alinhadas com administrador/urls.py)
        self.list_users_url = reverse('admin-user-list') 
        self.detail_user_url = reverse('admin-user-detail', kwargs={'pk': self.user_alvo.pk})
        self.stats_url = reverse('admin-dashboard-stats')
        self.logs_url = reverse('admin-log-list')


# --- TESTES DE PERMISSÃO E CRUD (AdminUserViewSet) ---

class AdminUserManagementTests(AdminBaseAPITestCase):
    
    # --- TESTES DE LEITURA (GET) ---

    def test_list_users_as_admin_success(self):
        """
        [GET /api/admin/users/] Admin pode listar todos os usuários.
        """
        self.client.force_authenticate(user=self.user_admin)
        response = self.client.get(self.list_users_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Deve ver todos os 3 usuários (Admin, Médico, Alvo)
        self.assertEqual(len(response.data), 3) 

    def test_list_users_as_non_admin_forbidden(self):
        """
        [GET /api/admin/users/] Usuário comum (Médico) é barrado (403).
        """
        self.client.force_authenticate(user=self.user_medico)
        response = self.client.get(self.list_users_url)
        
        # A permissão IsAdminUser deve barrar
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_retrieve_user_as_admin_success(self):
        """
        [GET /api/admin/users/{id}/] Admin pode ver detalhes do usuário.
        """
        self.client.force_authenticate(user=self.user_admin)
        response = self.client.get(self.detail_user_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['cpf'], self.user_alvo.cpf)

    # --- TESTES DE CRIAÇÃO (POST) ---

    @patch('administrador.views.AdminUserViewSet.send_creation_email') # Simula o envio de email
    def test_create_paciente_and_log_as_admin(self, mock_send_mail):
        """
        [POST /api/admin/users/] Cria um PACIENTE com sucesso e verifica logs.
        """
        user_count_before = User.objects.count()
        log_count_before = LogEntry.objects.count()

        self.client.force_authenticate(user=self.user_admin)
        data = {
            'cpf': '33333333333', 
            'email': 'novo@paciente.com',
            'password': 'temp_password',
            'first_name': 'Novo', 
            'last_name': 'Paciente',
            'user_type': 'PACIENTE',
            'telefone': '99887766' # Campo extra para o perfil
        }
        
        response = self.client.post(self.list_users_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(User.objects.count(), user_count_before + 1)
        self.assertFalse(mock_send_mail.called) # Pacientes não recebem email de criação

        # Verifica se o perfil de Paciente foi criado
        novo_user = User.objects.get(cpf='33333333333')
        self.assertTrue(Paciente.objects.filter(user=novo_user).exists())
        self.assertEqual(Paciente.objects.get(user=novo_user).telefone, '99887766')
        
        # Verifica se o LogEntry foi criado
        self.assertEqual(LogEntry.objects.count(), log_count_before + 1)
        log = LogEntry.objects.latest('timestamp')
        self.assertEqual(log.action_type, LogEntry.ActionType.CREATE)
        self.assertIn('Criou o utilizador', log.details)


    @patch('administrador.views.AdminUserViewSet.send_creation_email')
    def test_create_medico_required_fields(self, mock_send_mail):
        """
        [POST /api/admin/users/] Cria um MEDICO e verifica o envio de email.
        """
        self.client.force_authenticate(user=self.user_admin)
        data = {
            'cpf': '44444444444', 
            'email': 'novo@medico.com',
            'password': 'temp_password',
            'first_name': 'Novo', 
            'last_name': 'Medico',
            'user_type': 'MEDICO',
            'crm': '12345-MG', # Obrigatório para Médico
            'especialidade': 'CARDIOLOGIA', # Obrigatório para Médico
            'clinica_id': self.clinica.pk # Opcional/Auxiliar
        }
        
        response = self.client.post(self.list_users_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(mock_send_mail.called) # Médicos recebem email de criação
        self.assertTrue(Medico.objects.filter(user__cpf='44444444444').exists())

    def test_create_medico_missing_crm_fails(self):
        """
        [POST /api/admin/users/] Falha se faltar CRM para Médico.
        """
        self.client.force_authenticate(user=self.user_admin)
        data = {
            'cpf': '55555555555', 
            'email': 'fail@medico.com',
            'password': 'temp_password',
            'user_type': 'MEDICO',
            'especialidade': 'CARDIOLOGIA',
            # Falta 'crm'
        }
        
        response = self.client.post(self.list_users_url, data, format='json')
        
        # Espera-se falha na validação do perform_create
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('CRM e Especialidade são obrigatórios', str(response.data))
        self.assertFalse(User.objects.filter(cpf='55555555555').exists()) # O User deve ser deletado

    def test_create_user_as_non_admin_forbidden(self):
        """
        [POST /api/admin/users/] Usuário comum (Médico) é barrado.
        """
        self.client.force_authenticate(user=self.user_medico)
        data = {
            'cpf': '66666666666', 
            'email': 'naopode@criar.com',
            'user_type': 'PACIENTE',
            'password': 'pode'
        }
        
        response = self.client.post(self.list_users_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(User.objects.count(), 3) # Nenhum usuário novo


    # --- TESTES DE ATUALIZAÇÃO (PUT/PATCH) ---

    def test_update_user_password_and_log(self):
        """
        [PUT /api/admin/users/{id}/] Atualiza senha e verifica log.
        """
        log_count_before = LogEntry.objects.count()
        
        self.client.force_authenticate(user=self.user_admin)
        data = {
            'cpf': self.user_alvo.cpf, # Deve ser incluído para o serializer
            'email': self.user_alvo.email,
            'password': 'new_secure_password', # Nova senha
            'first_name': 'Usuario', 
            'last_name': 'Alvo Atualizado', # Novo nome
            'user_type': self.user_alvo.user_type,
        }
        
        response = self.client.put(self.detail_user_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # 1. Verifica se a senha foi alterada
        self.user_alvo.refresh_from_db()
        self.assertTrue(self.user_alvo.check_password('new_secure_password'))
        self.assertEqual(self.user_alvo.last_name, 'Alvo Atualizado')
        
        # 2. Verifica o LogEntry
        self.assertEqual(LogEntry.objects.count(), log_count_before + 1)
        log = LogEntry.objects.latest('timestamp')
        self.assertEqual(log.action_type, LogEntry.ActionType.UPDATE)
        self.assertIn('Atualizou o utilizador', log.details)


    # --- TESTES DE REMOÇÃO (DELETE) ---

    def test_delete_user_and_log_as_admin(self):
        """
        [DELETE /api/admin/users/{id}/] Remove usuário e verifica log.
        """
        self.client.force_authenticate(user=self.user_admin)
        
        response = self.client.delete(self.detail_user_url)
        
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        
        # 1. Verifica se o usuário foi removido
        self.assertFalse(User.objects.filter(pk=self.user_alvo.pk).exists())

        # 2. Verifica o LogEntry
        log = LogEntry.objects.latest('timestamp')
        self.assertEqual(log.action_type, LogEntry.ActionType.DELETE)
        self.assertIn('Removeu o utilizador', log.details)


# --- TESTES DE AUDITORIA E STATS ---

class AdminAuditAndStatsTests(AdminBaseAPITestCase):

    def test_dashboard_stats_success(self):
        """
        [GET /api/admin/stats/] Admin pode ver estatísticas agregadas.
        """
        self.client.force_authenticate(user=self.user_admin)
        response = self.client.get(self.stats_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verifica os dados: 3 criados no setup (Admin, Médico, Alvo)
        self.assertEqual(response.data['total'], 3)
        self.assertEqual(response.data['active'], 3)
        self.assertEqual(response.data['doctors'], 1) 
        self.assertEqual(response.data['patients'], 1)
        self.assertEqual(response.data['secretaries'], 0) # Nenhuma secretaria criada no setup

    def test_logs_list_success(self):
        """
        [GET /api/admin/logs/] Admin pode listar logs de auditoria.
        """
        # Criar logs de exemplo (não vamos usar os logs de create/update/delete)
        LogEntry.objects.create(
            actor=self.user_admin, 
            action_type=LogEntry.ActionType.LOGIN, 
            details="Login de admin"
        )
        
        self.client.force_authenticate(user=self.user_admin)
        response = self.client.get(self.logs_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['action_type'], LogEntry.ActionType.LOGIN)

