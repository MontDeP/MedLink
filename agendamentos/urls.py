from django.urls import path
from .views import ConsultaAPIView, ConsultaStatusUpdateView, PagamentoUpdateView, AnotacaoConsultaView, FinalizarConsultaAPIView, PacienteMarcarConsultaView, PacienteRemarcarConsultaView

urlpatterns = [
    # Listar/criar consultas
    path('', ConsultaAPIView.as_view(), name='agendamentos-list-create'),
    # Detalhar/editar/deletar consulta específica
    path('<int:pk>/', ConsultaAPIView.as_view(), name='agendamentos-detail-delete'),
    # Atualizar status da consulta
    path('<int:pk>/status/', ConsultaStatusUpdateView.as_view(), name='agendamentos-status-update'),
    # Atualizar pagamento da consulta
    path('<int:pk>/pagamento/', PagamentoUpdateView.as_view(), name='agendamentos-pagamento-update'),
    # Anotação da consulta
    path('<int:pk>/anotacao/', AnotacaoConsultaView.as_view(), name='agendamentos-anotacao'),
    # Finalizar consulta
    path('<int:pk>/finalizar/', FinalizarConsultaAPIView.as_view(), name='agendamentos-finalizar'),

    path('paciente-marcar/', PacienteMarcarConsultaView.as_view(), name='paciente-marcar-consulta' ),
    path('<int:pk>/paciente-remarcar/', PacienteRemarcarConsultaView.as_view(), name='paciente-remarcar-consulta'),
]