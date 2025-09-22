from django.contrib import admin
from .models import Consulta, Pagamento, ConsultaStatusLog

# Configuração para exibir o histórico de status de forma aninhada
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

# Configuração para exibir o pagamento de forma aninhada
class PagamentoInline(admin.TabularInline):
    model = Pagamento
    extra = 0
    fields = ('status', 'valor_pago', 'data_pagamento')
    readonly_fields = ('data_criacao', 'data_atualizacao')
    max_num = 1
    
# Registra o modelo Consulta no painel de administração
@admin.register(Consulta)
class ConsultaAdmin(admin.ModelAdmin):
    list_display = ('id', 'paciente', 'medico', 'data_hora', 'status_atual', 'valor')
    list_filter = ('status_atual', 'clinica', 'medico', 'data_hora')
    search_fields = ('paciente__nome_completo', 'medico__first_name', 'clinica__nome_fantasia')
    
    inlines = [PagamentoInline, ConsultaStatusLogInline]

    def get_inline_instances(self, request, obj=None):
        if not obj:
            return []
        return super().get_inline_instances(request, obj)
