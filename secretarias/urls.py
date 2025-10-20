# secretarias/urls.py

from django.urls import path
from .views import (
    DashboardStatsView,
    ConsultasHojeView,
    ConfirmarConsultaView,
    CancelarConsultaView,
)

urlpatterns = [
    # URL para os cards de estatísticas
    path('dashboard/stats/', DashboardStatsView.as_view(), name='dashboard-stats'),

    # URL para a lista de consultas de hoje
    path('dashboard/consultas-hoje/', ConsultasHojeView.as_view(), name='consultas-hoje'),

    # URLs para as ações de confirmar e cancelar. O '<int:pk>' é um placeholder para o ID da consulta.
    path('consultas/<int:pk>/confirmar/', ConfirmarConsultaView.as_view(), name='confirmar-consulta'),
    path('consultas/<int:pk>/cancelar/', CancelarConsultaView.as_view(), name='cancelar-consulta'),
]