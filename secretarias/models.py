# secretarias/models.py
from django.db import models
from django.conf import settings
from clinicas.models import Clinica
from django.utils.translation import gettext_lazy as _
from users.models import User

class Secretaria(models.Model):
    """
    Modelo de Perfil para a Secretária, ligado ao modelo User principal.
    """
    # Relação 1-para-1 com o modelo User.
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='perfil_secretaria' # Nome explícito para o acesso reverso
    )

    # Relação com a clínica. Se a clínica for deletada, o perfil da secretária também é.
    clinica = models.ForeignKey(
        Clinica,
        on_delete=models.CASCADE,
        related_name='secretarias',
        verbose_name="Clínica"
    )
    
    # Campo para data de nascimento, opcional e consistente com o modelo Médico.
    data_nascimento = models.DateField(_("Data de Nascimento"), null=True, blank=True)

    class Meta:
        verbose_name = "Secretária"
        verbose_name_plural = "Secretárias"
        ordering = ['user__first_name', 'user__last_name']

    def __str__(self):
        clinica_nome = self.clinica.nome_fantasia if self.clinica else 'Sem clínica'
        return f"{self.user.get_full_name()} - {clinica_nome}"
    
    @property
    def clinic_name(self):
        """Helper para acessar o nome da clínica de forma segura"""
        return self.clinica.nome if self.clinica else None

class SecretariaUser(User):
    """Modelo Proxy para tratar utilizadores do tipo Secretária no admin."""
    class Meta:
        proxy = True
        verbose_name = 'Secretária (Utilizador)'
        verbose_name_plural = 'Secretárias (Utilizadores)'