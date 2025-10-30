# pacientes/models.py
from django.db import models
from users.models import User
from django.conf import settings

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
    
    # Campos da UI (Altura, Peso, Idade, Sangue)
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
    
    # Renomeando 'dados_clinicos' para corresponder à UI
    informacoes_adicionais = models.TextField(blank=True, verbose_name="Informações Adicionais")
    

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