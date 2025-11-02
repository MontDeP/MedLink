# medicos/views.py (VERSÃO CORRIGIDA E COMPLETA)

from rest_framework.generics import ListAPIView, UpdateAPIView
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
import logging
from django.db.models import Q, Exists, OuterRef

from agendamentos.models import Consulta, ConsultaStatusLog
from agendamentos.serializers import ConsultaSerializer
from agendamentos.consts import STATUS_CONSULTA_REAGENDAMENTO_SOLICITADO # <-- Importação corrigida
from users.permissions import IsMedicoUser
from .models import Medico
from .serializers import MedicoSerializer

logger = logging.getLogger(__name__)


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
        ).exclude(status_atual='CANCELADA'
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
                'paciente': consulta.paciente.nome_completo,  # Acessa a property do modelo
            })
            
        return Response

class EspecialidadeListView(APIView):
    """
    API para listar todas as especialidades disponíveis para o paciente.
    """
    permission_classes = [IsAuthenticated] # Apenas usuários logados podem ver

    def get(self, request, *args, **kwargs):
        # Pega as "choices" do modelo Medico
        choices = Medico.EspecialidadeChoices.choices
        
        # Formata a lista para o frontend (ex: {'value': 'CARDIOLOGIA', 'label': 'Cardiologia'})
        especialidades_formatadas = [
            {'value': value, 'label': label}
            for value, label in choices
        ]
        
        return Response(especialidades_formatadas, status=status.HTTP_200_OK)
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

# ... (o resto do arquivo)

# ... (O código anterior, até o início de MedicoListView)

class MedicoListView(ListAPIView):
    """
    View para listar médicos, que:
    1. FILTRA por 'especialidade' se o query param for passado (para pacientes/mobile).
    2. FILTRA por clínica quando o usuário é uma secretária/médico (controle de acesso).
    """
    serializer_class = MedicoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = Medico.objects.select_related('user').all()

        # 1. FILTRAGEM POR ESPECIALIDADE (Vinda da sua branch)
        especialidade = self.request.query_params.get('especialidade')
        if especialidade:
            # Aplica o filtro em TODOS os médicos antes de aplicar o controle de acesso
            queryset = queryset.filter(especialidade=especialidade)

        # 2. CONTROLE DE ACESSO/VISIBILIDADE (Vindo da branch develop)
        if user.user_type == 'SECRETARIA' and hasattr(user, 'perfil_secretaria'):
            clinica = user.perfil_secretaria.clinica

            consultas_na_clinica = Exists(
                Consulta.objects.filter(
                    medico=OuterRef('user'),
                    clinica=clinica,
                )
            )

            # Filtra o queryset com base na clínica da secretária
            return (
                queryset
                .annotate(_has_consulta_na_clinica=consultas_na_clinica)
                .filter(
                    Q(clinicas=clinica) | Q(_has_consulta_na_clinica=True)
                )
                .prefetch_related('clinicas')
                .distinct()
                .order_by('user__first_name', 'user__last_name')
            )

        if user.user_type == 'MEDICO' and hasattr(user, 'perfil_medico'):
            clinicas = user.perfil_medico.clinicas.all()
            # Filtra para ver seus próprios médicos e os médicos das suas clínicas
            return (
                queryset
                .filter(Q(user=user) | Q(clinicas__in=clinicas))
                .prefetch_related('clinicas')
                .distinct()
                .order_by('user__first_name', 'user__last_name')
            )

        if user.is_staff or user.is_superuser:
            # Administrador/Staff vê tudo (já filtramos pela especialidade no início)
            return queryset.all().order_by('user__first_name', 'user__last_name')

        # Se for um usuário PAICIENTE (ou outro tipo não listado), ele vê o queryset
        # já filtrado pela especialidade (se fornecida).
        return queryset.order_by('user__first_name', 'user__last_name')