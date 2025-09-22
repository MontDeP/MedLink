from django.urls import path
from .views import ConsultaAPIView, ConsultaStatusUpdateView, PagamentoUpdateView

urlpatterns = [
    # Rota para Listar e Criar agendamentos
    path('', ConsultaAPIView.as_view(), name='agendamentos-list-create'),
    
    # Rota para Visualizar e Deletar um agendamento específico
    path('<int:pk>/', ConsultaAPIView.as_view(), name='agendamentos-detail-delete'),
    
    # Rota para Atualizar o status de um agendamento
    path('<int:pk>/status/', ConsultaStatusUpdateView.as_view(), name='agendamentos-status-update'),
    
    # Rota para Marcar o pagamento de um agendamento
    path('<int:pk>/pagamento/', PagamentoUpdateView.as_view(), name='agendamentos-pagamento-update'),
]
