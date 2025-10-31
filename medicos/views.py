# medicos/views.py (VERSÃO CORRIGIDA E COMPLETA)

from rest_framework.generics import ListAPIView, UpdateAPIView
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

from agendamentos.models import Consulta, ConsultaStatusLog
from agendamentos.serializers import ConsultaSerializer
from agendamentos.consts import STATUS_CONSULTA_REAGENDAMENTO_SOLICITADO # <-- Importação corrigida
from users.permissions import IsMedicoUser
from .models import Medico
from .serializers import MedicoSerializer


# --- VIEW DA AGENDA (LÓGICA CORRIGIDA) ---
class MedicoAgendaAPIView(APIView):
    """
    Fornece as consultas de um mês específico para o médico logado,
    agrupadas por dia para o calendário.
    """
    permission_classes = [IsAuthenticated, IsMedicoUser]

    def get(self, request, *args, **kwargs):
        medico = request.user
        
        # Pega o ano e o mês dos parâmetros da URL (ex: /?year=2025&month=10)
        try:
            year = int(request.query_params.get('year'))
            month = int(request.query_params.get('month'))
        except (TypeError, ValueError):
            return Response(
                {"error": "Os parâmetros 'year' e 'month' são obrigatórios e devem ser números."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Filtra as consultas do médico para o mês e ano especificados
        consultas_do_mes = Consulta.objects.filter(
            medico=medico,
            data_hora__year=year,
            data_hora__month=month
        ).select_related('paciente__user').order_by('data_hora')

        # Agrupa as consultas por dia
        agenda_formatada = {}
        for consulta in consultas_do_mes:
            dia = consulta.data_hora.strftime('%Y-%m-%d')
            if dia not in agenda_formatada:
                agenda_formatada[dia] = []
            
            # Adiciona um objeto simples para cada consulta
            agenda_formatada[dia].append({
                'id': consulta.id,
                'horario': consulta.data_hora.strftime('%H:%M'),
                'paciente': consulta.paciente.nome_completo, # Acessa a property do modelo
            })
            
        return Response(agenda_formatada, status=status.HTTP_200_OK)


# --- O RESTO DO FICHEIRO CONTINUA IGUAL ---

class SolicitarReagendamentoAPIView(UpdateAPIView):
    """
    Endpoint para um médico solicitar o reagendamento de uma consulta.
    Altera o status da consulta para 'REAGENDAMENTO_SOLICITADO'.
    Utiliza o método PATCH ou PUT.
    """
    permission_classes = [IsAuthenticated, IsMedicoUser]
    queryset = Consulta.objects.all()
    serializer_class = ConsultaSerializer

    def update(self, request, *args, **kwargs):
        consulta = self.get_object()

        # Validação de segurança: o médico só pode alterar as suas próprias consultas
        if consulta.medico != request.user:
            return Response(
                {"detail": "Não autorizado a alterar esta consulta."},
                status=status.HTTP_403_FORBIDDEN
            )

        novo_status = STATUS_CONSULTA_REAGENDAMENTO_SOLICITADO

        # Altera o status da consulta
        consulta.status_atual = novo_status
        consulta.save()

        # Cria um registo no histórico de status para auditoria
        ConsultaStatusLog.objects.create(
            consulta=consulta,
            status_novo=novo_status,
            pessoa=request.user
        )
        
        serializer = self.get_serializer(consulta)
        return Response(serializer.data)


class MedicoListView(ListAPIView):
    """
    View para listar médicos, filtrando por clínica quando o usuário é uma secretária.
    """
    serializer_class = MedicoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        
        # Secretária: vê apenas médicos da sua clínica
        if user.user_type == 'SECRETARIA' and hasattr(user, 'perfil_secretaria'):
            clinica = user.perfil_secretaria.clinica
            return Medico.objects.filter(clinicas=clinica).distinct()
        
        # Admin: vê todos
        if user.is_staff or user.is_superuser:
            return Medico.objects.all()
            
        # Outros usuários: veem nada
        return Medico.objects.none()