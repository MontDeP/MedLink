# administrador/signals.py
from django.contrib.auth.signals import user_logged_in
from django.dispatch import receiver
from .models import LogEntry

@receiver(user_logged_in) # Ligação ao sinal de início de sessão
def log_user_login(sender, request, user, **kwargs):
    """
    Cria um registo de log sempre que um administrador inicia sessão.
    """
    LogEntry.objects.create(
        actor=user,
        action_type=LogEntry.ActionType.LOGIN,
        details=f"O utilizador {user.get_full_name()} (CPF: {user.cpf}) iniciou sessão."
    )