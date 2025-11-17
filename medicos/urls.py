# medicos/urls.py (VERSÃO CORRIGIDA)

from django.urls import path
from . import views
from .views import MedicoHorariosOcupadosView

urlpatterns = [
    path('agenda/', views.MedicoAgendaAPIView.as_view(), name='medico-agenda'),
    path('consultas/<int:pk>/solicitar-reagendamento/', views.SolicitarReagendamentoAPIView.as_view(), name='solicitar-reagendamento'),
    path('', views.MedicoListView.as_view(), name='medico-list'),
    path('buscar/', views.MedicoFilterView.as_view(), name='medico-buscar'),
    path('<int:medico_id>/horarios-ocupados/', MedicoHorariosOcupadosView.as_view(), name='medico-horarios-ocupados'),
]