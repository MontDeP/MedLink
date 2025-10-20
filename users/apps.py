# users/apps.py (Versão Correta)
from django.apps import AppConfig

class UsersConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'users'

    def ready(self):
        # Importa os sinais para que eles sejam conectados quando o app iniciar
        import users.signals