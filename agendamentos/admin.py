# agendamentos/admin.py
from django.contrib import admin
from .models import Consulta, Pagamento, ConsultaStatusLog

class ConsultaStatusLogInline(admin.TabularInline):
    model = ConsultaStatusLog
    extra = 0
    fields = ('status_novo', 'pessoa', 'data_modificacao')
    readonly_fields = ('status_novo', 'pessoa', 'data_modificacao')
    can_delete = False
    
    def has_add_permission(self, request, obj=None):
        return False
        
    def has_change_permission(self, request, obj=None):
        return False

class PagamentoInline(admin.TabularInline):
    model = Pagamento
    extra = 0
    fields = ('status', 'valor_pago', 'data_pagamento', 'data_criacao', 'data_atualizacao')
    readonly_fields = ('data_criacao', 'data_atualizacao') # Adicionado
    max_num = 1
    
@admin.register(Consulta)
class ConsultaAdmin(admin.ModelAdmin):
    list_display = ('id', 'paciente', 'medico', 'data_hora', 'status_atual', 'valor', 'data_criacao', 'data_atualizacao')
    list_filter = ('status_atual', 'clinica', 'medico', 'data_hora')
    search_fields = ('paciente__user__first_name', 'paciente__user__last_name', 'medico__first_name', 'clinica__nome_fantasia')
    
    # Adicionando campos apenas de leitura
    readonly_fields = ('data_criacao', 'data_atualizacao')
    
    inlines = [PagamentoInline, ConsultaStatusLogInline]

    def get_inline_instances(self, request, obj=None):
        if not obj:
            return []
        return super().get_inline_instances(request, obj)