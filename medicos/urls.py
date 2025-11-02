# medicos/urls.py (VERSÃO ATUALIZADA)

from django.urls import path
from .views import MedicoAgendaAPIView, SolicitarReagendamentoAPIView, MedicoListView, EspecialidadeListView

urlpatterns = [
    # 👇 ROTA NOVA ADICIONADA AQUI 👇
    path('agenda/', MedicoAgendaAPIView.as_view(), name='medico-agenda'),
    path('especialidades/', EspecialidadeListView.as_view(), name='especialidade-list'),
    path('consultas/<int:pk>/solicitar-reagendamento/', SolicitarReagendamentoAPIView.as_view(), name='solicitar-reagendamento'),
    path('', MedicoListView.as_view(), name='medico-list'),
]