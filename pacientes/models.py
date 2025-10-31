# pacientes/models.py
from django.db import models
from users.models import User
from django.conf import settings
from clinicas.models import Clinica

# Modelo Paciente que se LIGA ao User através de uma relação One-to-One
class Paciente(models.Model):
    # Ligação 1 para 1 com o modelo de usuário customizado.
    # Usar settings.AUTH_USER_MODEL é a melhor prática.
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        primary_key=True, # Transforma o campo 'user' na chave primária da tabela.
    )

    # Campos específicos do paciente
    telefone = models.CharField(max_length=15, blank=True)
    data_cadastro = models.DateTimeField(auto_now_add=True)
    dados_clinicos = models.TextField(blank=True)
    clinica = models.ForeignKey(
        Clinica,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='pacientes'
    )

    def __str__(self):
        # Acessa os dados do modelo User relacionado
        return self.user.get_full_name() or self.user.cpf

    @property
    def nome_completo(self):
        return f"{self.user.first_name} {self.user.last_name}"

    class Meta:
        verbose_name = 'Paciente'
        verbose_name_plural = 'Pacientes'