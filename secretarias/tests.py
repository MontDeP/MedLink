# secretarias/tests.py

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal

# Importa modelos da app em teste
from .models import Secretaria
from .serializers import DashboardStatsSerializer, ConsultaHojeSerializer

# Importa modelos das apps dependentes
from clinicas.models import Clinica, Cidade, Estado, TipoClinica
from pacientes.models import Paciente
from agendamentos.models import Consulta, ConsultaStatusLog
# Importa constantes para criar os dados de teste com os status corretos
from agendamentos.consts import STATUS_CONSULTA_CONFIRMADA, STATUS_CONSULTA_PENDENTE, STATUS_CONSULTA_CONCLUIDA

# Pega o modelo de User customizado
User = get_user_model()


# --- CLASSE BASE PARA SETUP DE DADOS ---
class BaseSecretariaAPITestCase(APITestCase):
    """
    Cria um ecossistema completo de dados necessário para testar a Secretária.
    """
    def setUp(self):
        # Configurações de Data
        self.today = timezone.now().date()
        # Cria um datetime sem microsegundos para facilitar a comparação
        self.today_dt = timezone.now().replace(hour=10, minute=0, second=0, microsecond=0)
        self.next_month_dt = self.today_dt + timedelta(days=35)
        
        # 1. Criar Dados de Localização e Clínica
        estado = Estado.objects.create(nome="Tocantins", uf="TO")
        cidade = Cidade.objects.create(nome="Palmas", estado=estado)
        tipo_clinica = TipoClinica.objects.create(descricao="Geral")
        self.clinica = Clinica.objects.create(
            nome_fantasia="Clínica Teste", cidade=cidade, tipo_clinica=tipo_clinica, cnpj="11222333000144"
        )
        
        # 2. Criar Utilizadores e Perfis
        self.user_secretaria = User.objects.create_user(
            cpf='44444444444', email='sec@email.com', password='senha',
            first_name='Secretaria', last_name='Teste', user_type='SECRETARIA'
        )
        self.secretaria = Secretaria.objects.create(
            user=self.user_secretaria, clinica=self.clinica
        )
        
        self.user_paciente = User.objects.create_user(
            cpf='11111111111', email='pac@email.com', password='senha',
            first_name='Paciente', last_name='Teste', user_type='PACIENTE'
        )
        self.paciente = Paciente.objects.create(user=self.user_paciente)
        
        self.user_medico = User.objects.create_user(
            cpf='22222222222', email='med@email.com', password='senha',
            first_name='Dr.', last_name='Medico', user_type='MEDICO'
        )
        
        # 3. Criar Consultas (para o Dashboard)
        # Consulta para HOJE (PENDENTE - Contagem 1)
        self.consulta_hoje_pendente = Consulta.objects.create(
            paciente=self.paciente, medico=self.user_medico, clinica=self.clinica,
            data_hora=self.today_dt, valor=Decimal('150.00'), status_atual=STATUS_CONSULTA_PENDENTE
        )
        
        # Consulta para HOJE (CONFIRMADA - Contagem 2)
        self.consulta_hoje_confirmada = Consulta.objects.create(
            paciente=self.paciente, medico=self.user_medico, clinica=self.clinica,
            data_hora=self.today_dt + timedelta(hours=2), valor=Decimal('250.00'), status_atual=STATUS_CONSULTA_CONFIRMADA
        )
        
        # Consulta para o MÊS (TOTAL MÊS - Contagem 3)
        self.consulta_mes = Consulta.objects.create(
            paciente=self.paciente, medico=self.user_medico, clinica=self.clinica,
            data_hora=self.today_dt + timedelta(days=1), valor=Decimal('100.00'), status_atual='AGENDADA' # Usamos AGENDADA que é o valor da constante
        )
        
        # Consulta para OUTRO MÊS (Deve ser ignorada pelo filtro de mês)
        Consulta.objects.create(
            paciente=self.paciente, medico=self.user_medico, clinica=self.clinica,
            data_hora=self.next_month_dt, valor=Decimal('100.00'), status_atual='AGENDADA'
        )


# --- TESTES DE MODELO ---

class SecretariaModelTests(TestCase):
    """
    Testes para o Modelo Secretaria, alinhado com secretarias/models.py.
    """
    
    def setUp(self):
        # Criar dados de dependência para o teste de modelo
        estado = Estado.objects.create(nome="Tocantins", uf="TO")
        cidade = Cidade.objects.create(nome="Palmas", estado=estado)
        tipo_clinica = TipoClinica.objects.create(descricao="Geral")
        self.clinica = Clinica.objects.create(
            nome_fantasia="Clínica Teste", cidade=cidade, tipo_clinica=tipo_clinica, cnpj="11222333000144"
        )
        self.user_secretaria = User.objects.create_user(
            cpf='44444444444', email='sec@email.com', password='senha',
            first_name='Secretaria', last_name='Teste', user_type='SECRETARIA'
        )

    def test_secretaria_creation(self):
        """
        Verifica se o perfil Secretaria é criado corretamente com a relação OneToOne.
       
        """
        secretaria = Secretaria.objects.create(user=self.user_secretaria, clinica=self.clinica)
        self.assertEqual(Secretaria.objects.count(), 1)
        self.assertEqual(secretaria.user, self.user_secretaria)
        self.assertEqual(secretaria.clinica, self.clinica)
        # O campo 'user' é primary_key, então o pk deve ser igual ao user.pk
        self.assertEqual(secretaria.pk, self.user_secretaria.pk)

    def test_secretaria_str_method(self):
        """
        Verifica se o método __str__ retorna o nome completo do usuário.
       
        """
        secretaria = Secretaria.objects.create(user=self.user_secretaria, clinica=self.clinica)
        self.assertEqual(str(secretaria), 'Secretaria Teste')


# --- TESTES DE SERIALIZER ---

class SecretariaSerializerTests(BaseSecretariaAPITestCase):
    """
    Testes para os Serializers da app Secretarias.
    """
    
    def test_dashboard_stats_serializer(self):
        """
        Verifica se o DashboardStatsSerializer valida o formato de dados corretamente.
       
        """
        # Dados esperados do setUp: today=2, confirmed=1, pending=1, totalMonth=3
        stats_data = {
            'today': 2,
            'confirmed': 1,
            'pending': 1,
            'totalMonth': 3
        }
        
        serializer = DashboardStatsSerializer(data=stats_data)
        
        self.assertTrue(serializer.is_valid())
        self.assertEqual(serializer.data['totalMonth'], 3)

    def test_consulta_hoje_serializer_data(self):
        """
        Verifica se o ConsultaHojeSerializer retorna os campos corretos e formatados.
       
        """
        # Usamos a consulta confirmada
        serializer = ConsultaHojeSerializer(instance=self.consulta_hoje_confirmada)
        data = serializer.data
        
        self.assertEqual(data['id'], self.consulta_hoje_confirmada.id)
        self.assertEqual(data['time'], '12:00') # 10:00 + 2h = 12:00
        self.assertEqual(data['patient'], 'Paciente Teste') # Fonte: paciente.nome_completo
        self.assertEqual(data['doctor'], 'Dr. Medico') # Fonte: medico.get_full_name
        self.assertIn('Confirmada', data['type']) 
        self.assertEqual(data['status'], 'confirmed') # get_status method


# --- TESTES DE API (VIEWS) ---

class SecretariaAPITests(BaseSecretariaAPITestCase):
    """
    Testes de Integração para as Views do Dashboard e Ações de Secretária.
    Aderência às URLs e permissões HasRole.
    """

    # --- Testes para DashboardStatsView (name='dashboard-stats') ---

    def test_dashboard_stats_success(self):
        """
        Testa GET /dashboard/stats/ com Secretária logada.
       
        """
        self.client.force_authenticate(user=self.user_secretaria)
        url = reverse('dashboard-stats')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.assertEqual(response.data['today'], 2)
        self.assertEqual(response.data['confirmed'], 1)
        self.assertEqual(response.data['pending'], 1)
        self.assertEqual(response.data['totalMonth'], 3)
        
    def test_dashboard_stats_forbidden_paciente(self):
        """
        Testa GET /dashboard/stats/ com Paciente logado (deve falhar por HasRole).
       
        """
        self.client.force_authenticate(user=self.user_paciente)
        url = reverse('dashboard-stats')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        
    def test_dashboard_stats_forbidden_medico(self):
        """
        Testa GET /dashboard/stats/ com Médico logado (deve falhar por HasRole).
       
        """
        self.client.force_authenticate(user=self.user_medico)
        url = reverse('dashboard-stats')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


    # --- Testes para ConsultasHojeView (name='consultas-hoje') ---

    def test_consultas_hoje_success(self):
        """
        Testa GET /dashboard/consultas-hoje/ com Secretária logada.
       
        """
        self.client.force_authenticate(user=self.user_secretaria)
        url = reverse('consultas-hoje')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)
        self.assertEqual(response.data[0]['time'], '10:00')
        self.assertEqual(response.data[1]['time'], '12:00')


    # --- Testes para ConfirmarConsultaView (name='confirmar-consulta') ---

    def test_confirmar_consulta_success(self):
        """
        Testa PATCH /consultas/{pk}/confirmar/
        Verifica se o status é atualizado (PENDENTE -> CONFIRMADA) e o log é criado.
       
        """
        self.client.force_authenticate(user=self.user_secretaria)
        url = reverse('confirmar-consulta', kwargs={'pk': self.consulta_hoje_pendente.pk})
        
        response = self.client.patch(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # 1. Verifica o status no banco de dados
        self.consulta_hoje_pendente.refresh_from_db()
        self.assertEqual(self.consulta_hoje_pendente.status_atual, 'CONFIRMADA')
        
        # 2. Verifica o log de auditoria
        log_exists = ConsultaStatusLog.objects.filter(
            consulta=self.consulta_hoje_pendente, 
            status_novo='CONFIRMADA', 
            pessoa=self.user_secretaria
        ).exists()
        self.assertTrue(log_exists)

    def test_confirmar_consulta_forbidden(self):
        """
        Testa PATCH /consultas/{pk}/confirmar/ com Paciente logado (deve falhar por HasRole).
       
        """
        self.client.force_authenticate(user=self.user_paciente)
        url = reverse('confirmar-consulta', kwargs={'pk': self.consulta_hoje_pendente.pk})
        response = self.client.patch(url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


    # --- Testes para CancelarConsultaView (name='cancelar-consulta') ---

    def test_cancelar_consulta_success(self):
        """
        Testa PATCH /consultas/{pk}/cancelar/ com motivo.
       
        """
        self.client.force_authenticate(user=self.user_secretaria)
        url = reverse('cancelar-consulta', kwargs={'pk': self.consulta_hoje_confirmada.pk})
        data = {'motivo': 'Paciente não pode comparecer'}
        
        response = self.client.patch(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # 1. Verifica o status no banco de dados
        self.consulta_hoje_confirmada.refresh_from_db()
        self.assertEqual(self.consulta_hoje_confirmada.status_atual, 'CANCELADA')
        
        # 2. Verifica o log de auditoria (deve conter o motivo)
        log = ConsultaStatusLog.objects.get(consulta=self.consulta_hoje_confirmada)
        self.assertEqual(log.status_novo, 'CANCELADA - Motivo: Paciente não pode comparecer')
        
    def test_cancelar_consulta_no_motivo_success(self):
        """
        Testa o cancelamento sem fornecer um motivo (deve usar o default).
       
        """
        self.client.force_authenticate(user=self.user_secretaria)
        url = reverse('cancelar-consulta', kwargs={'pk': self.consulta_hoje_pendente.pk})
        response = self.client.patch(url) # Sem body
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # 1. Verifica o status
        self.consulta_hoje_pendente.refresh_from_db()
        self.assertEqual(self.consulta_hoje_pendente.status_atual, 'CANCELADA')
        
        # 2. Verifica o log de auditoria (deve usar o motivo default)
        log = ConsultaStatusLog.objects.get(consulta=self.consulta_hoje_pendente)
        self.assertEqual(log.status_novo, 'CANCELADA - Motivo: Cancelado pela secretaria')