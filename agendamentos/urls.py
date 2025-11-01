from django.urls import path
from .views import ConsultaAPIView, ConsultaStatusUpdateView, PagamentoUpdateView, AnotacaoConsultaView, FinalizarConsultaAPIView, PacienteMarcarConsultaView, PacienteRemarcarConsultaView

urlpatterns = [
    path('', ConsultaAPIView.as_view(), name='agendamentos-list-create'),
    
    # CORREÇÃO: Deve ser <int:pk>
    path('<int:pk>/', ConsultaAPIView.as_view(), name='agendamentos-detail-delete'),
    
    # CORREÇÃO: Deve ser <int:pk>
    path('<int:pk>/status/', ConsultaStatusUpdateView.as_view(), name='agendamentos-status-update'),
    
    # CORREÇÃO: Deve ser <int:pk>
    path('<int:pk>/pagamento/', PagamentoUpdateView.as_view(), name='agendamentos-pagamento-update'),

    path('<int:pk>/anotacao/', AnotacaoConsultaView.as_view(), name='agendamentos-anotacao'),
    path('<int:pk>/finalizar/', FinalizarConsultaAPIView.as_view(), name='agendamentos-finalizar'),

    path('paciente-marcar/', PacienteMarcarConsultaView.as_view(), name='paciente-marcar-consulta' ),
    path('<int:pk>/paciente-remarcar/', PacienteRemarcarConsultaView.as_view(), name='paciente-remarcar-consulta'),
]