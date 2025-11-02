# secretarias/views.py

from datetime import date
from rest_framework.views import APIView
from rest_framework.generics import ListAPIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

# Importando os modelos e serializers necessários
from agendamentos.models import Consulta, ConsultaStatusLog
from .serializers import DashboardStatsSerializer, ConsultaHojeSerializer
from users.permissions import HasRole

# 1. IMPORTE AS CONSTANTES DE STATUS DO SEU APP DE AGENDAMENTOS
from agendamentos.consts import STATUS_CONSULTA_CONFIRMADA, STATUS_CONSULTA_PENDENTE


# ATENÇÃO: Verifique se sua classe de permissão está neste local e com este nome.
# Se for diferente, ajuste o import.
from users.permissions import HasRole

class DashboardStatsView(APIView):
    """
    Fornece os dados para os cards de estatísticas do dashboard.
    """
    permission_classes = [IsAuthenticated, HasRole]
    required_roles = ['SECRETARIA']

    def get(self, request):
        today = date.today()
        
        # Obtém a clínica da secretária logada
        clinica = request.user.perfil_secretaria.clinica
        
        # Filtra as consultas pela clínica
        consultas_do_dia = Consulta.objects.filter(
            data_hora__date=today,
            clinica=clinica
        )
        consultas_do_mes = Consulta.objects.filter(
            data_hora__year=today.year, 
            data_hora__month=today.month,
            clinica=clinica
        )

        # Contagens
        stats_data = {
            'today': consultas_do_dia.count(),
            
            # 👇 CORREÇÃO: USANDO AS CONSTANTES PARA GARANTIR CONSISTÊNCIA 👇
            'confirmed': consultas_do_dia.filter(status_atual=STATUS_CONSULTA_CONFIRMADA).count(),
            'pending': consultas_do_dia.filter(status_atual=STATUS_CONSULTA_PENDENTE).count(),
            
            'totalMonth': consultas_do_mes.count(),
        }

        serializer = DashboardStatsSerializer(data=stats_data)
        serializer.is_valid(raise_exception=True)
        return Response(serializer.data)

class ConsultasHojeView(ListAPIView):
    """
    Fornece a lista de consultas agendadas para o dia de hoje.
    """
    serializer_class = ConsultaHojeSerializer
    permission_classes = [IsAuthenticated, HasRole]
    required_roles = ['SECRETARIA']

    def get_queryset(self):
        today = date.today()
        # Filtra as consultas pela clínica da secretária
        clinica = self.request.user.perfil_secretaria.clinica
        
        # COMBINADO: Filtra pela data, pela clínica E exclui as consultas canceladas
        return Consulta.objects.filter(
            data_hora__date=today,
            clinica=clinica
        ).exclude(
            status_atual='CANCELADA' # Adicionado da sua feature mobile
        ).order_by('data_hora')


class ConfirmarConsultaView(APIView):
    """
    Endpoint para mudar o status de uma consulta para 'CONFIRMADA'.
    Recebe um PATCH request em /api/consultas/{id}/confirmar/
    """
    permission_classes = [IsAuthenticated, HasRole]
    required_roles = ['SECRETARIA']

    def patch(self, request, pk):
        try:
            # Filtra pela clínica da secretária
            clinica = request.user.perfil_secretaria.clinica
            consulta = Consulta.objects.get(pk=pk, clinica=clinica)
            
            consulta.status_atual = 'CONFIRMADA'
            consulta.save()

            # Cria um registro no log de auditoria
            ConsultaStatusLog.objects.create(
                status_novo='CONFIRMADA',
                consulta=consulta,
                pessoa=request.user
            )
            return Response({'message': 'Consulta confirmada com sucesso!'}, status=status.HTTP_200_OK)
        except Consulta.DoesNotExist:
            return Response(
                {'error': 'Consulta não encontrada ou não pertence à sua clínica.'}, 
                status=status.HTTP_404_NOT_FOUND
            )

class CancelarConsultaView(APIView):
    """
    Endpoint para mudar o status de uma consulta para 'CANCELADA'.
    Recebe um PATCH request em /api/consultas/{id}/cancelar/
    """
    permission_classes = [IsAuthenticated, HasRole]
    required_roles = ['SECRETARIA']

    def patch(self, request, pk):
        motivo = request.data.get('motivo', 'Cancelado pela secretaria')
        try:
            # Filtra pela clínica da secretária
            clinica = request.user.perfil_secretaria.clinica
            consulta = Consulta.objects.get(pk=pk, clinica=clinica)
            
            consulta.status_atual = 'CANCELADA'
            consulta.save()
            
            # Cria um registro no log de auditoria
            ConsultaStatusLog.objects.create(
                status_novo=f'CANCELADA - Motivo: {motivo}',
                consulta=consulta,
                pessoa=request.user
            )
            return Response({'message': 'Consulta cancelada com sucesso!'}, status=status.HTTP_200_OK)
        except Consulta.DoesNotExist:
            return Response(
                {'error': 'Consulta não encontrada ou não pertence à sua clínica.'}, 
                status=status.HTTP_404_NOT_FOUND
            )