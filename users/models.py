from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils.translation import gettext_lazy as _

class CustomUser(AbstractUser):
    """
    Modelo de usuário customizado que herda de AbstractUser.
    Inclui campos como 'nome' e 'cpf' para se adequar ao front-end.
    """
    nome = models.CharField(max_length=255, verbose_name=_('Nome'))
    
    cpf = models.CharField(max_length=11, unique=True, verbose_name=_('CPF'))

    class Meta:
        verbose_name = _("Usuário")
        verbose_name_plural = _("Usuários")

    def __str__(self):
        return self.nome
