# notificacoes/models.py

from django.db import models
from django.conf import settings # Para pegar o User model

class Notificacao(models.Model):
    class TipoNotificacao(models.TextChoices):
        AGENDAMENTO = 'AGENDAMENTO', 'Agendamento'
        SEGURANCA = 'SEGURANCA', 'Segurança'
        LEMBRETE = 'LEMBRETE', 'Lembrete'

    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='notificacoes'
    )

    titulo = models.CharField(max_length=100)
    mensagem = models.TextField()

    tipo = models.CharField(max_length=20, choices=TipoNotificacao.choices)
    lida = models.BooleanField(default=False)
    data_criacao = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notificação para {self.usuario.username}: {self.titulo}"

    class Meta:
        ordering = ['-data_criacao'] # Mais novas primeiro
        verbose_name_plural = "Notificações"