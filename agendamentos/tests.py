# agendamentos/tests.py (VERSÃO CORRIGIDA)

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.utils import timezone
from decimal import Decimal

# Modelos da app agendamentos
from .models import Consulta, Pagamento, AnotacaoConsulta, ConsultaStatusLog
# Modelos de outras apps necessários para criar dados
from pacientes.models import Paciente
from medicos.models import Medico
from secretarias.models import Secretaria
from clinicas.models import Clinica, Cidade, Estado, TipoClinica

# Serializers que vamos testar
from .serializers import (
    ConsultaSerializer, 
    PagamentoSerializer, 
    AnotacaoConsultaSerializer, 
    DashboardConsultaSerializer
)

# Constantes de status
from .consts import STATUS_PAGAMENTO_PENDENTE, STATUS_CONSULTA_CONCLUIDA

# Pega o modelo de User customizado
User = get_user_model()


# --- Testes de setUp (Funções Auxiliares) ---
class BaseAPITestCase(APITestCase):
    def setUp(self):
        # 1. Criar Utilizadores com diferentes papéis
        self.user_paciente = User.objects.create_user(
            cpf='11111111111', email='paciente.teste@email.com', password='password123',
            first_name='Paciente', last_name='Teste', user_type='PACIENTE'
        )
        self.user_medico = User.objects.create_user(
            cpf='22222222222', email='medico.teste@email.com', password='password123',
            first_name='Dr.', last_name='Medico', user_type='MEDICO'
        )
        self.user_medico_2 = User.objects.create_user(
            cpf='33333333333', email='medico.outro@email.com', password='password123',
            first_name='Dr.', last_name='Outro', user_type='MEDICO'
        )
        self.user_secretaria = User.objects.create_user(
            cpf='44444444444', email='secretaria.teste@email.com', password='password123',
            first_name='Secretaria', last_name='Teste', user_type='SECRETARIA'
        )

        # 2. Criar Perfis
        self.paciente = Paciente.objects.create(user=self.user_paciente, telefone='111111')
        self.medico = Medico.objects.create(user=self.user_medico, crm='12345-TO')
        self.medico_2 = Medico.objects.create(user=self.user_medico_2, crm='67890-SP')
        
        # 3. Criar Clínica e associar a Secretária
        estado = Estado.objects.create(nome="Tocantins", uf="TO")
        cidade = Cidade.objects.create(nome="Palmas", estado=estado)
        tipo_clinica = TipoClinica.objects.create(descricao="Geral")
        self.clinica = Clinica.objects.create(
            nome_fantasia="MedLink Testes", cidade=cidade, tipo_clinica=tipo_clinica, cnpj="11222333000144"
        )
        self.secretaria = Secretaria.objects.create(user=self.user_secretaria, clinica=self.clinica)

        # 4. Criar Consulta (o objeto principal dos testes)
        self.consulta = Consulta.objects.create(
            paciente=self.paciente,
            medico=self.user_medico, 
            clinica=self.clinica,
            data_hora=timezone.now() + timezone.timedelta(days=10),
            valor=Decimal('200.00')
        )
        
        # 5. Criar o Pagamento
        self.pagamento = Pagamento.objects.create(consulta=self.consulta)


# --- Testes de Modelo (models.py) ---

class AgendamentoModelTests(TestCase):
    def setUp(self):
        base = BaseAPITestCase()
        base.setUp()
        self.consulta = base.consulta
        self.user_medico = base.user_medico
        self.pagamento = base.pagamento 

    def test_consulta_creation_defaults(self):
        self.assertEqual(Consulta.objects.count(), 1)
        self.assertEqual(self.consulta.status_atual, 'PENDENTE') # O default do modelo

    def test_pagamento_creation_defaults(self):
        self.assertEqual(Pagamento.objects.count(), 1)
        # O campo é 'status'
        self.assertEqual(self.pagamento.status, STATUS_PAGAMENTO_PENDENTE)

    def test_anotacao_consulta_creation(self):
        # O modelo AnotacaoConsulta não tem o campo 'medico'
        anotacao = AnotacaoConsulta.objects.create(
            consulta=self.consulta,
            conteudo="Paciente reportou dor de cabeça."
        )
        self.assertEqual(AnotacaoConsulta.objects.count(), 1)
        self.assertEqual(anotacao.consulta, self.consulta)

    def test_consulta_status_log_creation(self):
        log = ConsultaStatusLog.objects.create(
            consulta=self.consulta,
            status_novo='CONFIRMADO',
            pessoa=self.user_medico
        )
        self.assertEqual(ConsultaStatusLog.objects.count(), 1) # Só este log
        self.assertEqual(log.status_novo, 'CONFIRMADO')


# --- Testes de Serializer (serializers.py) ---

class AgendamentoSerializerTests(BaseAPITestCase):

    def test_consulta_serializer_method_fields(self):
        AnotacaoConsulta.objects.create(
            consulta=self.consulta, conteudo="Teste de anotação"
        )
        serializer = ConsultaSerializer(instance=self.consulta)
        data = serializer.data

        # A chave é 'nome_completo'
        self.assertEqual(data['paciente_detalhes']['nome_completo'], 'Paciente Teste')
        self.assertEqual(data['medico_detalhes']['nome_completo'], 'Dr. Medico')
        self.assertEqual(data['clinica_detalhes']['nome_fantasia'], 'MedLink Testes')
        self.assertEqual(data['anotacao_conteudo'], "Teste de anotação")

    def test_consulta_serializer_create_method(self):
        """
        Testa o método 'create' do ConsultaSerializer.
        Ele deve criar APENAS a Consulta.
       
        """
        data = {
            "paciente": self.paciente.pk,
            "medico": self.user_medico.pk, 
            "clinica": self.clinica.pk,
            "data_hora": timezone.now() + timezone.timedelta(days=5),
            "valor": "300.00",
            "tipo_consulta": "PRIMEIRA_CONSULTA"
        }
        
        context = {'request': type('Request', (object,), {'user': self.user_secretaria})}
        serializer = ConsultaSerializer(data=data, context=context)
        
        self.assertTrue(serializer.is_valid(raise_exception=True))
        nova_consulta = serializer.save()

        self.assertEqual(Consulta.objects.count(), 2) # A do setUp + esta
        
        # O serializer.create não cria Pagamento nem Log.
        self.assertEqual(Pagamento.objects.count(), 1) # Apenas o do setUp
        self.assertEqual(ConsultaStatusLog.objects.count(), 0) # Nenhum log foi criado


# --- Testes de API (views.py) ---

class AgendamentoAPIViewTests(BaseAPITestCase):

    def test_list_consultas_como_medico(self):
        """
        Testa (GET /api/agendamentos/) para um Médico.
        Deve ver apenas as suas consultas.
        """
        Consulta.objects.create(
            paciente=self.paciente, medico=self.user_medico_2, clinica=self.clinica,
            data_hora=timezone.now() + timezone.timedelta(days=3), valor=100
        )
        self.client.force_authenticate(user=self.user_medico) 
        
        # O nome da URL é 'agendamentos-list-create'
        response = self.client.get(reverse('agendamentos-list-create'))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1) # Apenas a consulta dele

    def test_list_consultas_como_secretaria(self):
        """
        Testa (GET /api/agendamentos/) para uma Secretária.
        Deve ver todas as consultas da clínica.
        """
        Consulta.objects.create(
            paciente=self.paciente, medico=self.user_medico_2, clinica=self.clinica,
            data_hora=timezone.now() + timezone.timedelta(days=3), valor=100
        )
        self.client.force_authenticate(user=self.user_secretaria)
        
        response = self.client.get(reverse('agendamentos-list-create'))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2) # Vê as duas

    def test_list_consultas_como_paciente_forbidden(self):
        """
        Testa (GET /api/agendamentos/).
        Pacientes NÃO PODEM aceder a esta view.
        A view usa IsMedicoOrSecretaria.
        """
        self.client.force_authenticate(user=self.user_paciente) # <-- Login como Paciente
        response = self.client.get(reverse('agendamentos-list-create'))
        
        # O teste espera 403 (Proibido), que é o comportamento correto
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_create_consulta_via_api_post(self):
        """
        Testa (POST /api/agendamentos/)
        Verifica se a VIEW cria a Consulta, 
        o Pagamento e o StatusLog.
        """
        self.client.force_authenticate(user=self.user_secretaria)
        url = reverse('agendamentos-list-create')
        
        data = {
            "paciente": self.paciente.pk,
            "medico": self.user_medico.pk, 
            "clinica": self.clinica.pk,
            "data_hora": timezone.now() + timezone.timedelta(days=5),
            "valor": "300.00",
            "tipo_consulta": "PRIMEIRA_CONSULTA"
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        # A view DEVE criar todos os objetos
        self.assertEqual(Consulta.objects.count(), 2) # 1 do setUp + 1 da view
        self.assertEqual(Pagamento.objects.count(), 2) # 1 do setUp + 1 da view
        self.assertEqual(ConsultaStatusLog.objects.count(), 1) # 1 da view
        
        log = ConsultaStatusLog.objects.get(pessoa=self.user_secretaria)
        self.assertEqual(log.status_novo, 'PENDENTE') # O status default da consulta

    def test_create_consulta_conflito_horario_api(self):
        """
        NOVO TESTE (Substitui test_consulta_serializer_validate_conflito)
        Testa se a VIEW barra a criação 
        de consulta em horário conflitante.
        """
        self.client.force_authenticate(user=self.user_secretaria)
        url = reverse('agendamentos-list-create')
        
        data = {
            "paciente": self.paciente.pk,
            "medico": self.user_medico.pk, # Mesmo médico
            "clinica": self.clinica.pk,
            "data_hora": self.consulta.data_hora, # Mesmo horário da consulta do setUp
            "valor": "300.00",
            "tipo_consulta": "PRIMEIRA_CONSULTA"
        }
        
        response = self.client.post(url, data, format='json')
        
        # A view deve retornar 400 Bad Request
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)
        self.assertEqual(Consulta.objects.count(), 1) # Nada deve ser criado

    # --- Testes para ConsultaStatusUpdateView ---
    def test_update_status_como_secretaria(self):
        """
        Testa (PUT /api/agendamentos/<pk>/status/)
        """
        self.client.force_authenticate(user=self.user_secretaria)
        
        url = reverse('agendamentos-status-update', kwargs={'pk': self.consulta.pk})
        data = {'status_atual': 'CONFIRMADA'}
        
        # A view usa 'put'.
        response = self.client.put(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.consulta.refresh_from_db()
        self.assertEqual(self.consulta.status_atual, 'CONFIRMADA')
        
        log_exists = ConsultaStatusLog.objects.filter(
            consulta=self.consulta, status_novo='CONFIRMADA', pessoa=self.user_secretaria
        ).exists()
        self.assertTrue(log_exists)

    def test_update_status_como_paciente_forbidden(self):
        """
        Testa permissões para (PUT /api/agendamentos/<pk>/status/)
        """
        self.client.force_authenticate(user=self.user_paciente)
        
        url = reverse('agendamentos-status-update', kwargs={'pk': self.consulta.pk})
        data = {'status_atual': 'CONFIRMADA'}
        response = self.client.put(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    # --- Testes para PagamentoUpdateView ---
    def test_update_pagamento_como_secretaria(self):
        """
        Testa (PUT /api/agendamentos/<pk>/pagamento/)
        """
        self.client.force_authenticate(user=self.user_secretaria)
        
        url = reverse('agendamentos-pagamento-update', kwargs={'pk': self.consulta.pk}) # O PK é o da Consulta
        
        data = {'status': 'PAGO'}
        
        response = self.client.put(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.pagamento.refresh_from_db()
        self.assertEqual(self.pagamento.status, 'PAGO') 

    def test_update_pagamento_como_medico_forbidden(self):
        """
        Testa permissões para (PUT /api/agendamentos/<pk>/pagamento/)
        Espera falhar
        """
        self.client.force_authenticate(user=self.user_medico)
        
        url = reverse('agendamentos-pagamento-update', kwargs={'pk': self.consulta.pk})
        data = {'status': 'PAGO'}
        response = self.client.put(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    # --- Testes para FinalizarConsultaAPIView ---
    def test_finalizar_consulta_como_medico(self):
        """
        Testa (POST /api/agendamentos/<pk>/finalizar/)
        """
        self.client.force_authenticate(user=self.user_medico) 
        
        url = reverse('agendamentos-finalizar', kwargs={'pk': self.consulta.pk})
        
        # A view espera a chave 'conteudo'
        data = {'conteudo': 'Paciente liberado.'}
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.consulta.refresh_from_db()
        
        self.assertEqual(self.consulta.status_atual, STATUS_CONSULTA_CONCLUIDA) 
        
        anotacao_exists = AnotacaoConsulta.objects.filter(
            consulta=self.consulta, conteudo="Paciente liberado."
        ).exists()
        self.assertTrue(anotacao_exists)

        log_exists = ConsultaStatusLog.objects.filter(
            consulta=self.consulta, status_novo=STATUS_CONSULTA_CONCLUIDA, pessoa=self.user_medico
        ).exists()
        self.assertTrue(log_exists)

    def test_finalizar_consulta_outro_medico_forbidden(self):
        """
        Testa lógica de "dono" para (POST /api/agendamentos/<pk>/finalizar/)
        """
        self.client.force_authenticate(user=self.user_medico_2) 
        
        url = reverse('agendamentos-finalizar', kwargs={'pk': self.consulta.pk})
        data = {'conteudo': 'Tentativa de invasão.'}
        response = self.client.post(url, data, format='json')

        # A view usa get_object_or_404 com filtro no user, então retorna 404
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_finalizar_consulta_como_secretaria_forbidden(self):
        """
        Testa permissões para (POST /api/agendamentos/<pk>/finalizar/)
        """
        self.client.force_authenticate(user=self.user_secretaria)
        
        url = reverse('agendamentos-finalizar', kwargs={'pk': self.consulta.pk})
        data = {'conteudo': '...'}
        response = self.client.post(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)