from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone

from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from unittest.mock import patch # Import para "simular" o envio de email
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes

User = get_user_model()

class UserModelTests(TestCase):
    '''
    Testes para o modelo CustomUser
    '''
    def setUp(self):
        self.user = User.objects.create_user(
            cpf = '15223069005',
            email = 'mello.testesemail@gmail.com',
            password = 'senhaSegura123',
            first_name = 'Usuario',
            last_name = 'Testes',
            user_type = 'PACIENTE'
        )
        
    def test_create_user(self):
            """
            Testa se o utilizador foi criado corretamente no setUp.
            """
            # Buscamos o utilizador da base de dados de teste
            user = User.objects.get(cpf='15223069005')

            # Verifica os campos
            self.assertEqual(user.cpf, '15223069005')
            self.assertEqual(user.email, 'mello.testesemail@gmail.com')
            self.assertEqual(user.first_name, 'Usuario')
            self.assertEqual(user.last_name, 'Testes')
            self.assertEqual(user.user_type, 'PACIENTE')

            #verificações de senha
            self.assertFalse(user.password == 'senhaSegura123')
            self.assertTrue(user.check_password('senhaSegura123'))
            
            # Verifica os valores padrão
            self.assertTrue(user.is_active)
            self.assertFalse(user.is_staff)
            self.assertFalse(user.is_superuser)

            # Verifica o método __str__ 
            self.assertEqual(str(user), 'Usuario Testes')
            
            # Verifica a data (usando timezone para segurança)
            self.assertEqual(user.date_joined.date(), timezone.now().date())
            

class UserViewTests(APITestCase):
    '''
    Testes para as views(endpoints API) relacionadas ao User
    '''
    def setUp(self):
        self.user = User.objects.create_user(
            cpf='54566231020',
            email='logintest@medlink.com',
            password='senhaLogin123',
            first_name='Testa',
            last_name='Login',
            user_type='PACIENTE'
        )
    # --- Testes de Login
    def test_login_success(self):
        '''
        Testa se um utilizador consegue fazer login com credenciais válidas.
        '''
        # A URL 'token_obtain_pair' está em medlink_core/urls.py
        url = reverse('token_obtain_pair')
        data = {
            'cpf': '54566231020',
            'password': 'senhaLogin123'
        }
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data) 
        self.assertIn('refresh', response.data)
        
    def test_login_failure(self):
        '''
        Testa se o login falha com credenciais invalidas
        '''
        
        url = reverse('token_obtain_pair')
        data = {
            'cpf': '54566231020',
            'password': 'senhaErrada587'
        }
        
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        
    # --- Testes de Reset de Senha
    @patch('users.views.send_mail')
    def test_password_reset_request_success(self, mock_send_mail):
        '''
        Testa a PasswordResetRequestView.
        '''
        
        url = reverse('users:request-password-reset')
        data = {'email': 'logintest@medlink.com'}
        
        response = self.client.post(url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        #verifica se o email foi "enviado"
        self.assertTrue(mock_send_mail.called)
        
    def test_password_reset_request_email_nao_existe(self):
        """
        Testa a PasswordResetRequestView com um email que não existe.
        """
        url = reverse('users:request-password-reset')
        data = {'email': 'naoexiste@medlink.com'}
        
        response = self.client.post(url, data, format='json')
        
        # A view retorna 404 neste caso
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_password_reset_confirm_sucesso(self):
        """
        Testa a PasswordResetConfirmView para definir uma nova senha.
        Usa o nome da URL: 'reset-password-confirm'
        """
        # 1. Gerar o 'uid' e 'token'
        user = self.user
        token = default_token_generator.make_token(user)
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        
        # 2. Definir a URL
        url = reverse('users:reset-password-confirm')
        data = {
            'uid': uid,
            'token': token,
            'password': 'novaSenhaSegura123'
        }
        
        # 3. Fazer a chamada à API
        response = self.client.post(url, data, format='json')
        
        # 4. Verificar se a API respondeu OK
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # 5. Verificar se a senha foi realmente alterada
        user.refresh_from_db() 
        self.assertTrue(user.check_password('novaSenhaSegura123'))
        
        # 6. Verificar se o utilizador foi reativado
        self.assertTrue(user.is_active)