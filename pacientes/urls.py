# pacientes/urls.py (VERSÃO ATUALIZADA)

from django.urls import path
# 1. Importe a nova view que vamos criar
from .views import PacienteCreateView, PacienteListView, PacientesDoDiaAPIView, HistoricoPacienteAPIView 

urlpatterns = [
    path('register/', PacienteCreateView.as_view(), name='paciente-register'),
    path('', PacienteListView.as_view(), name='paciente-list'),
    path('hoje/', PacientesDoDiaAPIView.as_view(), name='pacientes-do-dia'),

    # 2. Adicione esta nova rota para o histórico
    path('<int:pk>/historico/', HistoricoPacienteAPIView.as_view(), name='paciente-historico'),
]