# pacientes/views.py (VERSÃO CORRIGIDA - Corrigindo o FieldError do select_related)

from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from rest_framework.response import Response
from django.utils import timezone
from .models import Paciente
from agendamentos.models import Consulta
from users.permissions import IsMedicoOrSecretaria
# --- MINHA ADIÇÃO DE IMPORT ---
from .serializers import PacienteCreateSerializer, PacienteProfileSerializer
# --- FIM DA MINHA ADIÇÃO ---
from agendamentos.serializers import ConsultaSerializer
from agendamentos.serializers import ConsultaSerializer, DashboardConsultaSerializer
from users.models import User

# View para CRIAR pacientes (Esta classe estava faltando no seu arquivo anterior)
class PacienteCreateView(generics.CreateAPIView):
    queryset = Paciente.objects.all()
    serializer_class = PacienteCreateSerializer
    permission_classes = [AllowAny]

# View para LISTAR todos os pacientes (Esta classe também estava faltando)
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
        ).exclude(status_atual='CANCELADA').select_related( # <-- ADICIONE O EXCLUDE AQUI
            'paciente__user', 'medico__perfil_medico'
        ).order_by('data_hora')
        
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
    
# --- VIEW DO HISTÓRICO (sem alterações) ---
class HistoricoPacienteAPIView(APIView):
    permission_classes = [IsAuthenticated, IsMedicoOrSecretaria]

    def get(self, request, pk, *args, **kwargs):
        medico = request.user
        
        historico_consultas = Consulta.objects.filter(
            paciente__user_id=pk,
            medico=medico
        ).select_related(
            'paciente__user', 'medico__perfil_medico'
        ).order_by('-data_hora')

        serializer = ConsultaSerializer(historico_consultas, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
# --- ✨ PacienteDashboardView (A VIEW CORRIGIDA) ✨ ---
class PacienteDashboardView(APIView):
    """
    View para carregar os dados dinâmicos da home page (dashboard) do paciente.
    """
    permission_classes = [IsAuthenticated] 

    def get(self, request): 
        usuario_logado = request.user

        if usuario_logado.user_type != User.UserType.PACIENTE:
            return Response({"erro": "Acesso negado. Esta view é para pacientes."}, status=403)
        
        try:
            paciente = Paciente.objects.get(user=usuario_logado)
        except Paciente.DoesNotExist:
            return Response({"erro": "Perfil de paciente não encontrado."}, status=404)

        nome_paciente = usuario_logado.get_full_name()

        # --- 1. Busca TODAS as consultas futuras (como OBJETOS) ---
        # --- ✨ CORREÇÃO AQUI: Removido 'medico__user' do select_related ✨ ---
        consultas_futuras = Consulta.objects.filter(
            paciente=paciente,
            data_hora__gte=timezone.now()
        ).select_related(
            'medico__perfil_medico', 'clinica' # 'medico__user' foi removido daqui
        ).order_by('data_hora')

        # 2. A "próxima consulta" é apenas a primeira desta lista
        proxima_consulta = consultas_futuras.first()

        # 3. Contexto para o Serializer
        serializer_context = {'request': request}

        # 4. Serializa a próxima consulta (se existir)
        dados_proxima_consulta = None
        if proxima_consulta:
            dados_proxima_consulta = DashboardConsultaSerializer(
                proxima_consulta, 
                context=serializer_context
            ).data

        # 5. Serializa TODAS as consultas futuras
        dados_todas_consultas = DashboardConsultaSerializer(
            consultas_futuras, 
            many=True, 
            context=serializer_context
        ).data
        
        # 6. Monta a resposta final
        response_data = {
            "nomePaciente": nome_paciente,
            "proximaConsulta": dados_proxima_consulta,
            "todasConsultas": dados_todas_consultas 
        }
        
        return Response(response_data)

class PacienteProfileView(generics.RetrieveUpdateAPIView):
    """
    API para o paciente logado (Retrieve) ver e (Update) atualizar 
    seu próprio perfil de paciente.
    """
    serializer_class = PacienteProfileSerializer
    permission_classes = [IsAuthenticated] # Só usuários logados

    def get_object(self):
        paciente, created = Paciente.objects.get_or_create(user=self.request.user)
        return paciente
