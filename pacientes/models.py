# pacientes/models.py
from django.db import models
from users.models import User
from django.conf import settings
from clinicas.models import Clinica

class Paciente(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        primary_key=True,
    )

    # Campos básicos
    telefone = models.CharField(max_length=15, blank=True)
    data_cadastro = models.DateTimeField(auto_now_add=True)

    # Clínica vinculada
    clinica = models.ForeignKey(
        Clinica,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='pacientes'
    )

    # Campos de perfil (UI)
    altura_cm = models.PositiveIntegerField(null=True, blank=True, verbose_name="Altura (cm)")
    peso_kg = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True, verbose_name="Peso (kg)")
    data_nascimento = models.DateField(null=True, blank=True, verbose_name="Data de Nascimento")

    TIPO_SANGUINEO_CHOICES = [
        ('A+', 'A+'), ('A-', 'A-'), ('B+', 'B+'), ('B-', 'B-'),
        ('AB+', 'AB+'), ('AB-', 'AB-'), ('O+', 'O+'), ('O-', 'O-'),
    ]
    tipo_sanguineo = models.CharField(
        max_length=3,
        choices=TIPO_SANGUINEO_CHOICES,
        null=True,
        blank=True
    )

    # Endereço
    cep = models.CharField(max_length=9, blank=True, verbose_name="CEP")
    bairro = models.CharField(max_length=100, blank=True)
    quadra = models.CharField(max_length=100, blank=True)
    av_rua = models.CharField(max_length=255, blank=True, verbose_name="Av/Rua")
    numero = models.CharField(max_length=20, blank=True)

    # Observações/Informações adicionais (usado no app)
    informacoes_adicionais = models.TextField(blank=True, verbose_name="Informações Adicionais")

    # Legado (mantido para compatibilidade, pode ser removido após migração)
    dados_clinicos = models.TextField(blank=True)

    def __str__(self):
        # Acessa os dados do modelo User relacionado
        return self.user.get_full_name() or self.user.cpf

    @property
    def nome_completo(self):
        # O 'get_full_name' do User já faz isso.
        return self.user.get_full_name()

    class Meta:
        verbose_name = 'Paciente'
        verbose_name_plural = 'Pacientes'