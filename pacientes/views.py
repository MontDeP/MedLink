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
from agendamentos.serializers import ConsultaSerializer, DashboardConsultaSerializer
from users.models import User

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
    
class PacienteDashboardView(APIView):
    """
    View para carregar os dados dinâmicos da home page (dashboard) do paciente.
    """
    permission_classes = [IsAuthenticated] # Exige autenticação

    def get(self, request):
        usuario_logado = request.user

        # 1. Validação: Apenas usuários do tipo PACIENTE podem acessar
        if usuario_logado.user_type != User.UserType.PACIENTE: #
            return Response({"erro": "Acesso negado. Esta view é para pacientes."}, status=403)
        
        try:
            # 2. Busca o perfil Paciente (ligado ao User pela PK)
            #
            paciente = Paciente.objects.get(user=usuario_logado)
        except Paciente.DoesNotExist:
            return Response({"erro": "Perfil de paciente não encontrado."}, status=404)

        # 3. Busca o nome do paciente (que está no model User)
        nome_paciente = usuario_logado.get_full_name() #

        # 4. Busca a próxima consulta
        proxima_consulta = Consulta.objects.filter(
            paciente=paciente,
            data_hora__gte=timezone.now() # Filtra por datas futuras
        ).select_related(
            'medico__perfil_medico', 'clinica' # Otimiza a query
        ).order_by('data_hora').first()

        # 5. Serializa os dados da consulta (se houver)
        dados_consulta = None
        if proxima_consulta:
            # Usa o NOVO serializer otimizado
            dados_consulta = DashboardConsultaSerializer(proxima_consulta).data

        # 6. Monta a resposta final no formato que o Flutter espera
        response_data = {
            "nomePaciente": nome_paciente,
            "proximaConsulta": dados_consulta # Será null se não houver consulta
        }
        
        return Response(response_data)