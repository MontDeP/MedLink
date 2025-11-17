# medicos/views.py (VERSÃO CORRIGIDA E COMPLETA)

from rest_framework.generics import ListAPIView, UpdateAPIView
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
import logging
from django.db.models import Q, Exists, OuterRef
from .serializers import MedicoListSerializer # Importe o novo serializer
from rest_framework import permissions

from agendamentos.models import Consulta, ConsultaStatusLog
from agendamentos.serializers import ConsultaSerializer
from agendamentos.consts import STATUS_CONSULTA_REAGENDAMENTO_SOLICITADO # <-- Importação corrigida
from agendamentos.consts import STATUS_CONSULTA_PENDENTE, STATUS_CONSULTA_CONFIRMADA
from users.permissions import IsMedicoUser
from .models import Medico
from .serializers import MedicoSerializer
from datetime import datetime

logger = logging.getLogger(__name__)


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
            data_hora__month=month,
            # vvvv FILTRO PARA MOSTRAR APENAS ATIVAS vvvv
            status_atual__in=[STATUS_CONSULTA_PENDENTE, STATUS_CONSULTA_CONFIRMADA]
            # ^^^^ ISSO EXCLUI CANCELADAS E REAGENDADAS ^^^^
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

        if user.user_type == 'SECRETARIA' and hasattr(user, 'perfil_secretaria'):
            clinica = user.perfil_secretaria.clinica

            # Fallback: inclui médicos que já possuem consultas nessa clínica,
            # mesmo que o M2M `clinicas` ainda não esteja preenchido.
            consultas_na_clinica = Exists(
                Consulta.objects.filter(
                    medico=OuterRef('user'),
                    clinica=clinica,
                )
            )

            return (
                Medico.objects
                .annotate(_has_consulta_na_clinica=consultas_na_clinica)
                .filter(
                    Q(clinicas=clinica) | Q(_has_consulta_na_clinica=True)
                )
                .select_related('user')
                .prefetch_related('clinicas')
                .distinct()
                .order_by('user__first_name', 'user__last_name')
            )

        if user.user_type == 'MEDICO' and hasattr(user, 'perfil_medico'):
            clinicas = user.perfil_medico.clinicas.all()
            return (Medico.objects
                    .filter(Q(user=user) | Q(clinicas__in=clinicas))
                    .select_related('user')
                    .prefetch_related('clinicas')
                    .distinct()
                    .order_by('user__first_name', 'user__last_name'))

        if user.is_staff or user.is_superuser:
            return Medico.objects.select_related('user').all().order_by('user__first_name', 'user__last_name')

        return Medico.objects.none()
    

class MedicoFilterView(APIView):
    """
    View para buscar médicos com base nos filtros (query params)
    de clinica_id e especialidade.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # 1. Obter os query params
        clinica_id = request.query_params.get('clinica_id')
        especialidade = request.query_params.get('especialidade')

        # 2. Validação inicial
        if not clinica_id or not especialidade:
            return Response({"error": "clinica_id e especialidade são obrigatórios."}, status=400)

        try:
            # 3. Filtrar o queryset
            medicos = Medico.objects.filter(
                clinicas__id=clinica_id,     # Filtra pela clínica (M2M)
                especialidade=especialidade  # Filtra pela especialidade
            ).select_related('user') # Otimiza pegando o 'user' junto

            # 4. Serializar os dados
            serializer = MedicoListSerializer(medicos, many=True)
            return Response(serializer.data)

        except ValueError:
            return Response({"error": "ID de clínica inválido."}, status=400)
        except Exception as e:
            return Response({"error": str(e)}, status=500)

# medicos/views.py

# ... (outras views, como MedicoFilterView) ...

class MedicoHorariosOcupadosView(APIView):
    """
    Endpoint para o paciente ver os horários *ocupados* de um médico
    para um dia específico, para desabilitar slots no front-end.
    """
    permission_classes = [permissions.IsAuthenticated] # Qualquer um logado pode ver

    def get(self, request, medico_id):
        # 1. Pega o parâmetro 'data' da URL (ex: ?data=2025-11-20)
        data_str = request.query_params.get('data')
        if not data_str:
            return Response(
                {"error": "O parâmetro 'data' (YYYY-MM-DD) é obrigatório."}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            data_selecionada = datetime.fromisoformat(data_str).date()
        except ValueError:
             return Response(
                {"error": "Formato de data inválido. Use YYYY-MM-DD."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # 2. Busca consultas que estão ativas (Pendentes ou Confirmadas)
        consultas = Consulta.objects.filter(
            medico_id=medico_id,
            data_hora__date=data_selecionada,
            status_atual__in=[STATUS_CONSULTA_PENDENTE, STATUS_CONSULTA_CONFIRMADA]
        )
        
        # 3. Retorna uma lista simples de horários (ISO strings)
        horarios_ocupados = [consulta.data_hora for consulta in consultas]
        
        return Response([h.isoformat() for h in horarios_ocupados], status=status.HTTP_200_OK)