# pacientes/views.py (VERSÃO FINAL CORRIGIDA)

from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from rest_framework.response import Response
from django.utils import timezone
from .models import Paciente
from agendamentos.models import Consulta
from users.permissions import IsMedicoOrSecretaria
from .serializers import PacienteCreateSerializer
from agendamentos.serializers import ConsultaSerializer

# View para CRIAR pacientes (sem alterações)
class PacienteCreateView(generics.CreateAPIView):
    queryset = Paciente.objects.all()
    serializer_class = PacienteCreateSerializer
    permission_classes = [AllowAny]

# View para LISTAR todos os pacientes (sem alterações)
class PacienteListView(generics.ListAPIView):
    queryset = Paciente.objects.select_related('user').all()
    serializer_class = PacienteCreateSerializer
    permission_classes = [IsAuthenticated]

# View para os PACIENTES DO DIA (sem alterações)
class PacientesDoDiaAPIView(APIView):
    permission_classes = [IsAuthenticated, IsMedicoOrSecretaria]
    def get(self, request, *args, **kwargs):
        medico = request.user
        hoje = timezone.now().date()
        consultas_de_hoje = Consulta.objects.filter(
            medico=medico,
            data_hora__date=hoje
        ).select_related('paciente__user', 'medico__perfil_medico').order_by('data_hora')
        
        dados_finais = []
        for consulta in consultas_de_hoje:
            dados_finais.append({
                "id": consulta.paciente.user.id,
                "consulta_id": consulta.id,
                "nome_completo": consulta.paciente.nome_completo,
                "email": consulta.paciente.user.email,
                "telefone": consulta.paciente.telefone,
                "cpf": consulta.paciente.user.cpf,
                "horario": consulta.data_hora,
                "status": consulta.status_atual,
                "profissional": consulta.medico.get_full_name(),
                "especialidade": consulta.medico.perfil_medico.get_especialidade_display()
            })
        return Response(dados_finais, status=status.HTTP_200_OK)
    
# --- VIEW DO HISTÓRICO (LÓGICA CORRIGIDA) ---
class HistoricoPacienteAPIView(APIView):
    """
    Retorna o histórico completo de consultas de um paciente específico
    com o médico logado.
    """
    permission_classes = [IsAuthenticated, IsMedicoOrSecretaria]

    def get(self, request, pk, *args, **kwargs):
        medico = request.user
        
        # CORREÇÃO: O filtro deve ser feito em 'paciente__user_id' porque o 'pk' que
        # recebemos é o ID do User, e o modelo Paciente tem a sua chave primária
        # ligada ao User.
        historico_consultas = Consulta.objects.filter(
            paciente__user_id=pk,
            medico=medico
        ).select_related(
            'paciente__user', 'medico__perfil_medico'
        ).order_by('-data_hora')

        serializer = ConsultaSerializer(historico_consultas, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)