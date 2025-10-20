# pacientes/admin.py
from django.contrib import admin
from .models import Paciente

@admin.register(Paciente)
class PacienteAdmin(admin.ModelAdmin):
    # Campos a serem exibidos na lista
    list_display = ('get_nome_completo', 'get_cpf', 'telefone', 'get_email', 'data_cadastro')

    # Campos de busca (já otimizados)
    search_fields = ('user__first_name', 'user__last_name', 'user__cpf', 'user__email')

    # Adicionando filtro por data de cadastro
    list_filter = ('data_cadastro',)

    # Adicionando campos apenas de leitura
    readonly_fields = ('data_cadastro',)

    # Métodos para obter os dados do modelo User relacionado (já otimizados)
    @admin.display(description='Nome Completo', ordering='user__first_name')
    def get_nome_completo(self, obj):
        return obj.user.get_full_name()

    @admin.display(description='CPF', ordering='user__cpf')
    def get_cpf(self, obj):
        return obj.user.cpf

    @admin.display(description='Email', ordering='user__email')
    def get_email(self, obj):
        return obj.user.email