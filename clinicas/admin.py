# clinicas/admin.py
from django.contrib import admin
from .models import Clinica, Cidade, Estado, TipoClinica

@admin.register(Estado)
class EstadoAdmin(admin.ModelAdmin):
    list_display = ('nome', 'uf')
    search_fields = ('nome', 'uf')

@admin.register(Cidade)
class CidadeAdmin(admin.ModelAdmin):
    list_display = ('nome', 'estado')
    search_fields = ('nome',)
    list_filter = ('estado',)

@admin.register(TipoClinica)
class TipoClinicaAdmin(admin.ModelAdmin):
    list_display = ('descricao',)
    search_fields = ('descricao',)

@admin.register(Clinica)
class ClinicaAdmin(admin.ModelAdmin):
    list_display = ('nome_fantasia', 'cnpj', 'cidade', 'tipo_clinica', 'responsavel')
    search_fields = ('nome_fantasia', 'cnpj')
    list_filter = ('cidade', 'tipo_clinica')
    raw_id_fields = ('cidade', 'responsavel')
    
    # Adicionando campos de data como apenas de leitura
    readonly_fields = ('data_criacao', 'data_atualizacao')
    # --- A SOLUÇÃO ESTÁ AQUI ---
    # Esta linha otimiza a consulta ao banco de dados, buscando os objetos
    # relacionados (cidade, tipo_clinica e responsavel) em uma única query.
    list_select_related = ('cidade', 'tipo_clinica', 'responsavel')