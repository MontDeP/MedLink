from django.db import models
from django.utils.translation import gettext_lazy as _
from users.models import CustomUser

class Paciente(models.Model):
    user = models.OneToOneField(
        CustomUser, 
        on_delete=models.CASCADE, 
        related_name='paciente',
        verbose_name=_('Usuário')
    )
    
    data_nascimento = models.DateField(
        null=True, 
        blank=True,
        verbose_name=_('Data de Nascimento')
    )
    
    telefone = models.CharField(max_length=15, verbose_name=_('Telefone'))
    data_cadastro = models.DateTimeField(auto_now_add=True, verbose_name=_('Data de Cadastro'))

    class Meta:
        verbose_name = _("Paciente")
        verbose_name_plural = _("Pacientes")
        
    def __str__(self):
        return self.user.nome
