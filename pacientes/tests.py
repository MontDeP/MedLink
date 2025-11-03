from django.test import TestCase
from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase
from rest_framework import status

from .models import Paciente
from .serializers import PacienteCreateSerializer, PacienteProfileSerializer
from agendamentos.models import Consulta
from clinicas.models import Clinica, Cidade, Estado, TipoClinica

from decimal import Decimal

User = get_user_model()

class PacienteModelTest(TestCase):
    """Testes para o modelo Paciente."""

    def setUp(self):
        """Cria um usuário base para os testes do modelo."""
        self.user = User.objects.create_user(
            cpf='12345678901',
            email='paciente.teste@email.com',
            password='password123',
            first_name='João',
            last_name='Silva',
            user_type='PACIENTE'
        )

    def test_paciente_creation(self):
        """Testa a criação de um perfil de Paciente associado a um User."""
        paciente = Paciente.objects.create(user=self.user, telefone='999998888')
        self.assertEqual(Paciente.objects.count(), 1)
        self.assertEqual(paciente.user, self.user)
        self.assertEqual(paciente.telefone, '999998888')
        # O campo 'user' é a chave primária
        self.assertEqual(paciente.pk, self.user.pk)

    def test_paciente_str_method(self):
        """Testa se o método __str__ retorna o nome completo do usuário."""
        paciente = Paciente.objects.create(user=self.user)
        self.assertEqual(str(paciente), 'João Silva')

    def test_paciente_nome_completo_property(self):
        """Testa se a property 'nome_completo' retorna o nome correto."""
        paciente = Paciente.objects.create(user=self.user)
        self.assertEqual(paciente.nome_completo, 'João Silva')


class PacienteSerializerTest(TestCase):
    """Testes para os serializers do app Pacientes."""

    def test_paciente_create_serializer(self):
        """Testa a criação de um User e Paciente via PacienteCreateSerializer."""
        data = {
            'cpf': '11122233344',
            'email': 'novo.paciente@email.com',
            'password': 'newpassword123',
            'first_name': 'Ana',
            'last_name': 'Souza',
            'telefone': '11987654321'
        }
        serializer = PacienteCreateSerializer(data=data)
        self.assertTrue(serializer.is_valid(raise_exception=True))
        paciente = serializer.save()

        # Verifica se o paciente e o usuário foram criados
        self.assertIsInstance(paciente, Paciente)
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(Paciente.objects.count(), 1)

        # Verifica os dados do usuário criado
        user = User.objects.get(cpf='11122233344')
        self.assertEqual(user.email, data['email'])
        self.assertEqual(user.get_full_name(), 'Ana Souza')
        self.assertEqual(user.user_type, 'PACIENTE')

        # Verifica os dados do paciente criado
        self.assertEqual(paciente.user, user)
        self.assertEqual(paciente.telefone, '11987654321')

    def test_paciente_profile_serializer_update(self):
        """Testa a atualização de dados aninhados (User e Paciente) via serializer."""
        user = User.objects.create_user(
            cpf='98765432109', email='antigo@email.com', password='password123',
            first_name='Carlos', last_name='Pereira'
        )
        paciente = Paciente.objects.create(
            user=user, telefone='111111111', tipo_sanguineo='A+'
        )

        data = {
            'user': {
                'first_name': 'Carlos Alberto', # Nome atualizado
                'last_name': 'Pereira'
            },
            'telefone': '222222222', # Telefone atualizado
            'tipo_sanguineo': 'O-' # Tipo sanguíneo atualizado
        }

        serializer = PacienteProfileSerializer(instance=paciente, data=data)
        self.assertTrue(serializer.is_valid(raise_exception=True))
        serializer.save()

        # Recarrega os dados do banco
        paciente.refresh_from_db()
        user.refresh_from_db()

        self.assertEqual(user.first_name, 'Carlos Alberto')
        self.assertEqual(paciente.telefone, '222222222')
        self.assertEqual(paciente.tipo_sanguineo, 'O-')


class PacienteAPIViewTest(APITestCase):
    """Testes para as Views (endpoints da API) do app Pacientes."""

    def setUp(self):
        """Cria usuários e dados de teste para os endpoints."""
        self.user_paciente = User.objects.create_user(
            cpf='55566677788', email='paciente.api@email.com', password='password123',
            first_name='Joana', last_name='Lima', user_type='PACIENTE'
        )
        self.paciente = Paciente.objects.create(user=self.user_paciente, telefone='333334444')

        self.user_medico = User.objects.create_user(
            cpf='99988877766', email='medico.api@email.com', password='password123',
            first_name='Dr. Ricardo', user_type='MEDICO'
        )

        # Dados para consultas
        estado = Estado.objects.create(nome="Rio de Janeiro", uf="RJ")
        cidade = Cidade.objects.create(nome="Rio de Janeiro", estado=estado)
        tipo_clinica = TipoClinica.objects.create(descricao="Cardiologia")
        self.clinica = Clinica.objects.create(nome_fantasia="Coração Forte", cidade=cidade, tipo_clinica=tipo_clinica, cnpj="11222333000144")
        valor = Decimal('150.00')
        
        self.consulta_futura = Consulta.objects.create(
            paciente=self.paciente,
            medico=self.user_medico,
            clinica=self.clinica,
            data_hora=timezone.now() + timezone.timedelta(days=5),
            valor = valor
        )

    def test_paciente_register_view(self):
        """Testa o endpoint de registro de um novo paciente (acesso público)."""
        url = reverse('paciente-register')
        data = {
            'cpf': '10203040506',
            'email': 'registro.api@email.com',
            'password': 'apipassword',
            'first_name': 'Mariana',
            'last_name': 'Campos',
            'telefone': '51999990000'
        }
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(cpf='10203040506').exists())
        self.assertTrue(Paciente.objects.filter(user__cpf='10203040506').exists())

    def test_paciente_profile_view_get(self):
        """Testa se um paciente logado pode ver seu próprio perfil."""
        url = reverse('paciente-profile')
        # Autentica como o paciente
        self.client.force_authenticate(user=self.user_paciente)
        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['user']['email'], self.user_paciente.email)
        self.assertEqual(response.data['telefone'], self.paciente.telefone)

    def test_paciente_profile_view_get_unauthenticated(self):
        """Testa que um usuário não autenticado não pode ver o perfil."""
        url = reverse('paciente-profile')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_paciente_profile_view_update(self):
        """Testa se um paciente logado pode atualizar seu próprio perfil."""
        url = reverse('paciente-profile')
        self.client.force_authenticate(user=self.user_paciente)

        update_data = {
            'user': {
                'first_name': 'Joana',
                'last_name': 'Lima da Silva' # Sobrenome atualizado
            },
            'telefone': '555556666' # Telefone atualizado
        }
        response = self.client.patch(url, update_data, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.paciente.refresh_from_db()
        self.assertEqual(self.paciente.telefone, '555556666')
        self.assertEqual(self.paciente.user.last_name, 'Lima da Silva')

    def test_paciente_dashboard_view(self):
        """Testa o endpoint do dashboard do paciente."""
        url = reverse('paciente-dashboard')
        self.client.force_authenticate(user=self.user_paciente)
        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['nomePaciente'], self.user_paciente.get_full_name())
        # Verifica se a próxima consulta e a lista de todas as consultas foram retornadas
        self.assertIsNotNone(response.data['proximaConsulta'])
        self.assertEqual(len(response.data['todasConsultas']), 1)
        self.assertEqual(response.data['proximaConsulta']['local'], self.clinica.nome_fantasia)

    def test_dashboard_access_denied_for_medico(self):
        """Garante que um médico não pode acessar o dashboard de um paciente."""
        url = reverse('paciente-dashboard')
        # Autentica como médico
        self.client.force_authenticate(user=self.user_medico)
        response = self.client.get(url)
        # A view deve retornar 403 Forbidden
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
