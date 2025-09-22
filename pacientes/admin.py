from django.contrib import admin
from .models import Paciente

@admin.register(Paciente)
class PacienteAdmin(admin.ModelAdmin):
    list_display = ("nome_completo", "cpf", "telefone", "email", "data_cadastro")
    search_fields = ("nome_completo", "cpf", "email")
