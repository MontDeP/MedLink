# medicos/tests.py

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.utils import timezone
from decimal import Decimal

# Importa os modelos e serializers que vamos testar
from .models import Medico
from .serializers import MedicoSerializer
from pacientes.models import Paciente
from agendamentos.models import Consulta, ConsultaStatusLog
from clinicas.models import Clinica, Cidade, Estado, TipoClinica
from agendamentos.consts import STATUS_CONSULTA_REAGENDAMENTO_SOLICITADO

# Pega o modelo de User customizado (definido em settings.py)
User = get_user_model()


class MedicoModelTests(TestCase):
    """
    Testes para a camada de Modelo (models.py).
    Verifica se a criação de dados e os métodos do modelo funcionam.
    """

    def setUp(self):
        """
        Executado antes de cada teste. 
        Cria um utilizador 'MEDICO' base para os testes.
        """
        self.user_medico = User.objects.create_user(
            cpf='11122233344',
            email='medico.teste@email.com',
            password='password123',
            first_name='Dr.',
            last_name='Teste',
            user_type='MEDICO' # Importante
        )

    def test_create_medico_profile(self):
        """
        Testa a criação de um perfil 'Medico' associado a um 'User'.
        """
        medico_profile = Medico.objects.create(
            user=self.user_medico,
            crm='12345-TO',
            especialidade='CLINICO_GERAL'
        )

        self.assertEqual(Medico.objects.count(), 1)
        self.assertEqual(medico_profile.user, self.user_medico)
        self.assertEqual(medico_profile.crm, '12345-TO')
        self.assertEqual(medico_profile.pk, self.user_medico.pk)

    def test_medico_str_method(self):
        """
        Testa o método __str__ do modelo Medico.
        Ele deve retornar o nome completo do utilizador.
        """
        medico_profile = Medico.objects.create(
            user=self.user_medico, crm='12345-TO'
        )

        expected_str = f"Dr(a). {self.user_medico.get_full_name()} (CRM: {medico_profile.crm})"
        self.assertEqual(str(medico_profile), expected_str)


class MedicoSerializerTests(TestCase):
    """
    Testes para a camada de Serialização (serializers.py).
    Verifica se os dados são convertidos para JSON corretamente.
    """

    def setUp(self):
        """
        Cria um User e um Medico para serem usados na serialização.
        """
        self.user_medico = User.objects.create_user(
            cpf='11122233344',
            email='medico.serializer@email.com',
            password='password123',
            first_name='Dra.',
            last_name='Ana',
            user_type='MEDICO'
        )
        self.medico_profile = Medico.objects.create(
            user=self.user_medico,
            crm='54321-SP',
            especialidade='CARDIOLOGIA'
        )

    def test_serializer_data_content(self):
        """
        Testa se o MedicoSerializer retorna os campos corretos
        e se o 'user_details' (SerializerMethodField) funciona.
        """
        serializer = MedicoSerializer(instance=self.medico_profile)

        expected_data = {
            'crm': '54321-SP',
            'especialidade': 'CARDIOLOGIA',
            'user': { 
                'id': self.user_medico.id,
                'full_name': 'Dra. Ana',
                'email': 'medico.serializer@email.com'
            }
        }

        self.assertEqual(serializer.data, expected_data)
        
        # Verifica se as chaves de nível superior estão corretas
        self.assertCountEqual(serializer.data.keys(), ['crm', 'especialidade', 'user'])


class MedicoAPIsTest(APITestCase):
    """
    Testes para as Views (endpoints da API) da app Medicos,
    baseado no ficheiro medicos/urls.py (VERSÃO ATUALIZADA).
    """

    def setUp(self):
        """
        Cria um ecossistema de dados para testar as permissões e lógicas:
        - 1 Médico
        - 1 Paciente
        - 1 Consulta ligando os dois
        """
        # 1. Criar o Paciente
        self.user_paciente = User.objects.create_user(
            cpf='11122233344', email='paciente.api@email.com', password='password123',
            first_name='Paciente', last_name='Teste', user_type='PACIENTE'
        )
        self.paciente = Paciente.objects.create(user=self.user_paciente, telefone='111111')

        # 2. Criar o Médico
        self.user_medico = User.objects.create_user(
            cpf='55566677788', email='medico.api@email.com', password='password123',
            first_name='Dr.', last_name='Ricardo', user_type='MEDICO'
        )
        self.medico = Medico.objects.create(
            user=self.user_medico, crm='99999-TO', especialidade='ORTOPEDIA'
        )

        # 3. Criar um segundo Médico (para testar permissões)
        self.user_medico_2 = User.objects.create_user(
            cpf='99988877766', email='medico.intruso@email.com', password='password123',
            first_name='Dr.', last_name='Intruso', user_type='MEDICO'
        )
        self.medico_2 = Medico.objects.create(
            user=self.user_medico_2, crm='11111-SP', especialidade='CARDIOLOGIA'
        )

        # 4. Criar dados de Clínica (necessários para a Consulta)
        estado = Estado.objects.create(nome="Tocantins", uf="TO")
        cidade = Cidade.objects.create(nome="Palmas", estado=estado)
        tipo_clinica = TipoClinica.objects.create(descricao="Geral")
        self.clinica = Clinica.objects.create(
            nome_fantasia="MedLink Testes", cidade=cidade, tipo_clinica=tipo_clinica, cnpj="11222333000144"
        )
        
        # 5. Criar uma Consulta (o objeto principal dos testes)
        # Vamos definir uma data específica para testar a agenda
        self.data_consulta = timezone.datetime(2025, 10, 15, 14, 30, tzinfo=timezone.get_current_timezone())
        
        self.consulta = Consulta.objects.create(
            paciente=self.paciente,
            medico=self.user_medico, # <-- Consulta pertence ao Medico 1
            clinica=self.clinica,
            data_hora=self.data_consulta,
            valor=Decimal('200.00') # Campo obrigatório que corrigimos antes
        )


    # --- Testes para MedicoListView (name='medico-list') ---
    
    def test_list_medicos_authenticated(self):
        """
        Testa GET /api/medicos/
        Qualquer utilizador autenticado (ex: Paciente) pode listar os médicos.
       
        """
        self.client.force_authenticate(user=self.user_paciente)
        
        url = reverse('medico-list') # URL: /api/medicos/
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Devemos ter 2 médicos na lista
        self.assertEqual(len(response.data), 2)
        # Verifica se o serializer está a trazer os dados corretos
        self.assertEqual(response.data[0]['crm'], self.medico_2.crm)

    def test_list_medicos_unauthenticated(self):
        """
        Testa GET /api/medicos/
        Utilizador não autenticado deve receber 401.
       
        """
        url = reverse('medico-list')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


    # --- Testes para MedicoAgendaAPIView (name='medico-agenda') ---

    def test_get_agenda_medico_sucesso(self):
        """
        Testa GET /api/medicos/agenda/?year=2025&month=10
        Testa se o médico logado vê a sua própria agenda formatada.
       
        """
        self.client.force_authenticate(user=self.user_medico)
        
        url = reverse('medico-agenda') # URL: /api/medicos/agenda/
        
        # Faz a requisição com os query parameters corretos
        response = self.client.get(url, {'year': 2025, 'month': 10})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verifica se a resposta está formatada como um dicionário de dias
        data_formatada = self.data_consulta.strftime('%Y-%m-%d') # "2025-10-15"
        self.assertIn(data_formatada, response.data)
        
        # Verifica o conteúdo da consulta
        self.assertEqual(len(response.data[data_formatada]), 1)
        self.assertEqual(response.data[data_formatada][0]['paciente'], 'Paciente Teste')

    def test_get_agenda_medico_sem_params(self):
        """
        Testa GET /api/medicos/agenda/ sem ?year e ?month
        Deve retornar 400 (Bad Request).
       
        """
        self.client.force_authenticate(user=self.user_medico)
        url = reverse('medico-agenda')
        
        response = self.client.get(url) # Sem query params
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)

    def test_get_agenda_paciente_forbidden(self):
        """
        Testa GET /api/medicos/agenda/
        Paciente não pode aceder (permissão IsMedicoUser).
       
        """
        self.client.force_authenticate(user=self.user_paciente) # <-- Login como Paciente
        
        url = reverse('medico-agenda')
        response = self.client.get(url, {'year': 2025, 'month': 10})
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


    # --- Testes para SolicitarReagendamentoAPIView (name='solicitar-reagendamento') ---

    def test_solicitar_reagendamento_sucesso(self):
        """
        Testa PATCH /api/medicos/consultas/<pk>/solicitar-reagendamento/
        Testa se o médico dono da consulta pode solicitar o reagendamento.
       
        """
        self.client.force_authenticate(user=self.user_medico) # <-- Login como Médico 1
        
        url = reverse('solicitar-reagendamento', kwargs={'pk': self.consulta.pk})
        
        # Usamos PATCH (ou PUT) pois é uma UpdateAPIView
        response = self.client.patch(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        # 1. Verifica se o status mudou na BD
        self.consulta.refresh_from_db()
        self.assertEqual(self.consulta.status_atual, STATUS_CONSULTA_REAGENDAMENTO_SOLICITADO)
        
        # 2. Verifica se o Log foi criado
        log_exists = ConsultaStatusLog.objects.filter(
            consulta=self.consulta,
            status_novo=STATUS_CONSULTA_REAGENDAMENTO_SOLICITADO,
            pessoa=self.user_medico
        ).exists()
        self.assertTrue(log_exists)

    def test_solicitar_reagendamento_outro_medico_forbidden(self):
        """
        Testa PATCH /api/medicos/consultas/<pk>/solicitar-reagendamento/
        Testa se o Médico 2 não pode reagendar a consulta do Médico 1.
       
        """
        self.client.force_authenticate(user=self.user_medico_2) # <-- Login como Médico 2
        
        url = reverse('solicitar-reagendamento', kwargs={'pk': self.consulta.pk})
        response = self.client.patch(url)
        
        # A lógica interna da view (if consulta.medico != request.user) retorna 403
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_solicitar_reagendamento_paciente_forbidden(self):
        """
        Testa PATCH /api/medicos/consultas/<pk>/solicitar-reagendamento/
        Testa se um Paciente não pode aceder (permissão IsMedicoUser).
       
        """
        self.client.force_authenticate(user=self.user_paciente) # <-- Login como Paciente
        
        url = reverse('solicitar-reagendamento', kwargs={'pk': self.consulta.pk})
        response = self.client.patch(url)
        
        # A permissão IsMedicoUser barra a entrada antes da lógica da view
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)