from django.apps import AppConfig


class AdministradorConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'administrador'

    def ready(self):
        # Importa os sinais para que eles sejam conectados quando a app for carregada.
        import administrador.signals