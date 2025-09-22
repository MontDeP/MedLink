# pacientes/models.py
from django.db import models

# pacientes/models.py
class Paciente(models.Model):
    nome_completo = models.CharField(max_length=255)
    data_nascimento = models.DateField()
    cpf = models.CharField(max_length=11, unique=True)
    telefone = models.CharField(max_length=15)
    email = models.EmailField(unique=True)  # <- adicione
    data_cadastro = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.nome_completo