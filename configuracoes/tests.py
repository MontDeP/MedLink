# configuracoes/tests.py

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.core.exceptions import ValidationError 

# Importa modelos e serializers da app 'configuracoes'
from .models import SystemSettings # O modelo singleton
from .serializers import SystemSettingsSerializer # O serializer da app

# Pega o modelo de User customizado
User = get_user_model()


# --- CLASSE BASE PARA SETUP DE ADMIN E DADOS ---
class AdminBaseAPITestCase(APITestCase):
    """
    Configura utilizadores Admin e Não-Admin (Médico) e a instância única 
    de SystemSettings para o ambiente de teste de API.
    """
    def setUp(self):
        # 1. ADMIN (Acesso Total) - Superuser (is_staff=True para IsAdminOrReadOnly)
        self.user_admin = User.objects.create_superuser(
            cpf='99999999999', 
            email='admin@config.com', 
            password='adminpassword',
            first_name='Admin',
            last_name='User',
        )

        # 2. NÃO-ADMIN (Acesso de Leitura) - Usuário autenticado mas sem privilégios de escrita
        self.user_medico = User.objects.create_user(
            cpf='11111111111', 
            email='medico@config.com', 
            password='userpassword',
            first_name='Dr.', 
            last_name='User', 
            user_type='MEDICO'
        )
        
        # 3. Cria a instância única de configuração (SystemSettings)
        # É criada com valores padrão que serão testados
        self.config = SystemSettings.objects.create(
            auto_scheduling=False,
            email_notifications=True,
            two_factor_auth=False,
            reminder_hours_before=24 
        )
        
        # 4. URL da API (usando o nome correto do urls.py)
        self.settings_url = reverse('system_settings')


# --- TESTES DE MODELO (models.py) ---

class SystemSettingsModelTests(TestCase):
    """
    Testes unitários para o modelo SystemSettings, focado na lógica de Singleton e Validação.
   
    """
    
    def test_singleton_logic_prevents_second_creation(self):
        """
        Verifica se a lógica de forçar o PK=1 na função save() impede a criação de 
        uma segunda instância válida na base de dados.
       
        """
        SystemSettings.objects.create(email_notifications=False)
        config2 = SystemSettings(email_notifications=True)
        
        # Espera que a tentativa de save() levante uma exceção de validação (IntegrityError subjacente)
        with self.assertRaises(ValidationError):
            config2.save() 
        
        self.assertEqual(SystemSettings.objects.count(), 1)

    def test_validation_clean_method_success(self):
        """
        Testa a validação do método clean() do modelo com um valor válido (0-168).
       
        """
        config = SystemSettings(reminder_hours_before=168)
        config.full_clean() # Não deve levantar erro

    def test_validation_clean_method_failure(self):
        """
        Testa se a validação customizada no clean() falha para um valor superior a 168.
       
        """
        config = SystemSettings(reminder_hours_before=200)
        
        with self.assertRaises(ValidationError) as cm:
             config.full_clean()
        
        self.assertIn("reminder_hours_before", cm.exception.message_dict)

    def test_model_str_method(self):
        """
        Verifica o método mágico __str__ do modelo.
       
        """
        config = SystemSettings.objects.create()
        self.assertEqual(str(config), "Configurações do Sistema (singleton)")


# --- TESTES DE SERIALIZER (serializers.py) ---

class SystemSettingsSerializerTests(TestCase):
    """
    Testes para o Serializer SystemSettingsSerializer.
    """
    
    def test_serializer_validation_success(self):
        """
        Verifica se o serializer aceita dados válidos e converte tipos corretamente.
        """
        data = {
            'auto_scheduling': True,
            'email_notifications': False,
            'two_factor_auth': True,
            'reminder_hours_before': 12
        }
        
        serializer = SystemSettingsSerializer(data=data)
        
        self.assertTrue(serializer.is_valid())
        self.assertIsInstance(serializer.validated_data['reminder_hours_before'], int)


# --- TESTES DE API (views.py) ---

class ConfiguracaoGlobalAPITests(AdminBaseAPITestCase):
    
    # --- Testes de Leitura (GET) ---

    def test_get_settings_as_admin_success(self):
        """
        [GET /api/config/settings/] Testa a leitura das configurações por um Admin.
        """
        self.client.force_authenticate(user=self.user_admin)
        response = self.client.get(self.settings_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['reminder_hours_before'], 24)

    def test_get_settings_as_non_admin_read_only(self):
        """
        [GET /api/config/settings/] Testa a leitura por um usuário comum (Médico).
        (Permitido pela regra IsAdminOrReadOnly)
        """
        self.client.force_authenticate(user=self.user_medico)
        response = self.client.get(self.settings_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    # --- Testes de Escrita (PATCH) ---
    
    def test_update_settings_as_admin_success(self):
        """
        [PATCH /api/config/settings/] Testa a atualização de dados pelo Admin.
        """
        self.client.force_authenticate(user=self.user_admin)
        
        data = {
            'auto_scheduling': True,
            'reminder_hours_before': 72
        }
        
        response = self.client.patch(self.settings_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # 1. Verifica se o banco de dados foi atualizado
        self.config.refresh_from_db()
        self.assertEqual(self.config.reminder_hours_before, 72)
        self.assertTrue(self.config.auto_scheduling)
        
    def test_update_settings_as_non_admin_forbidden(self):
        """
        [PATCH /api/config/settings/] Testa se o usuário comum é barrado na tentativa de escrita.
        (Proibido pela regra IsAdminOrReadOnly)
        """
        self.client.force_authenticate(user=self.user_medico)
        data = {'reminder_hours_before': 1}
        response = self.client.patch(self.settings_url, data, format='json')
        
        # A regra proíbe a escrita (PATCH/PUT) para não-admins
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_update_settings_invalid_data_fails(self):
        """
        [PATCH /api/config/settings/] Testa se a API retorna 400 Bad Request ao receber dados inválidos.
        (Esta validação deve ocorrer no serializer)
        """
        self.client.force_authenticate(user=self.user_admin)
        
        data = { 'reminder_hours_before': 300 } # Valor inválido (> 168)
        
        # A validação falha no serializer, retornando 400
        response = self.client.patch(self.settings_url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        
        # Verifica se o valor original não foi alterado
        self.config.refresh_from_db()
        self.assertEqual(self.config.reminder_hours_before, 24)