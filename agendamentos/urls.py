from django.urls import path
from .views import ConsultaAPIView, ConsultaStatusUpdateView, PagamentoUpdateView, AnotacaoConsultaView, FinalizarConsultaAPIView, PacienteMarcarConsultaView, PacienteRemarcarConsultaView, ClinicaListView, ClinicaEspecialidadeListView, EspecialidadeMedicoListView, MedicoHorariosDisponiveisView, PacienteCancelarConsultaView

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
    path('<int:pk>/paciente-cancelar/', PacienteCancelarConsultaView.as_view(), name='paciente-cancelar-consulta'),
    path('clinicas/', ClinicaListView.as_view(), name='agendamentos-clinica-list'),
    path('clinicas/<int:clinica_pk>/especialidades/', ClinicaEspecialidadeListView.as_view(), name='agendamentos-especialidades'),
    path('clinicas/<int:clinica_pk>/especialidades/<str:especialidade_key>/medicos/', EspecialidadeMedicoListView.as_view(), name='agendamentos-medicos'),
    path('medicos/<int:medico_pk>/horarios-disponiveis/', MedicoHorariosDisponiveisView.as_view(), name='medico-horarios-disponiveis'),
]