# medicos/urls.py (VERSÃO ATUALIZADA)

from django.urls import path
from .views import MedicoAgendaAPIView, SolicitarReagendamentoAPIView, MedicoListView

urlpatterns = [
    # 👇 ROTA NOVA ADICIONADA AQUI 👇
    path('agenda/', MedicoAgendaAPIView.as_view(), name='medico-agenda'),

    # Suas rotas existentes
    path('consultas/<int:pk>/solicitar-reagendamento/', SolicitarReagendamentoAPIView.as_view(), name='solicitar-reagendamento'),
    path('', MedicoListView.as_view(), name='medico-list'),
]