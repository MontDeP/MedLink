# administrador/models.py
from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _

class LogEntry(models.Model):
    """
    Modelo para registar ações importantes no sistema para fins de auditoria.
    """
    class ActionType(models.TextChoices):
        LOGIN = 'LOGIN', _('Login bem-sucedido')
        CREATE = 'CREATE', _('Criação de Objeto')
        UPDATE = 'UPDATE', _('Atualização de Objeto')
        DELETE = 'DELETE', _('Remoção de Objeto')
        PASSWORD_RESET = 'PASSWORD_RESET', _('Redefinição de Senha')

    # Quem realizou a ação. Pode ser nulo se a ação for do sistema.
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        verbose_name=_("Ator"),
        related_name='admin_logs'
    )
    action_type = models.CharField(
        max_length=20,
        choices=ActionType.choices,
        verbose_name=_("Tipo de Ação")
    )
    # Detalhes da ação em formato de texto.
    details = models.TextField(verbose_name=_("Detalhes"))
    
    timestamp = models.DateTimeField(auto_now_add=True, verbose_name=_("Data e Hora"))

    class Meta:
        verbose_name = _("Registo de Log")
        verbose_name_plural = _("Registos de Log")
        ordering = ['-timestamp'] # Ordena do mais recente para o mais antigo

    def __str__(self):
        actor_cpf = self.actor.cpf if self.actor else "Sistema"
        return f"{self.timestamp.strftime('%d/%m/%Y %H:%M')} - {actor_cpf} - {self.get_action_type_display()}"