# pacientes/views.py (VERSÃO CORRIGIDA)

from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from rest_framework.response import Response
from django.utils import timezone
from .models import Paciente
from agendamentos.models import Consulta
from agendamentos.consts import STATUS_CONSULTA_CONCLUIDA, STATUS_CONSULTA_PENDENTE, STATUS_CONSULTA_CANCELADA
from users.permissions import IsMedicoOrSecretaria
from users.models import User # Importação do modelo User
# --- MINHA ADIÇÃO DE IMPORT ---
from .serializers import PacienteCreateSerializer, PacienteProfileSerializer
# --- FIM DA MINHA ADIÇÃO ---
# Adiciona DashboardConsultaSerializer
from agendamentos.serializers import ConsultaSerializer, DashboardConsultaSerializer 
from django.db.models import Q

# View para CRIAR pacientes (Esta classe estava faltando no seu arquivo anterior)
class PacienteCreateView(generics.CreateAPIView):
    queryset = Paciente.objects.all()
    serializer_class = PacienteCreateSerializer
    permission_classes = [AllowAny]

# View para LISTAR todos os pacientes (sem alterações)
class PacienteListView(generics.ListAPIView):
    serializer_class = PacienteCreateSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user

        # Secretária: vê pacientes da sua clínica + pacientes que já tiveram consultas
        if user.user_type == 'SECRETARIA' and hasattr(user, 'perfil_secretaria'):
            clinica = user.perfil_secretaria.clinica
            return Paciente.objects.filter(
                Q(clinica=clinica) |  # Pacientes registrados na clínica
                Q(consultas_agendadas__clinica=clinica)  # Pacientes com consultas
            ).distinct()
        
        # Médico: vê seus pacientes + pacientes das clínicas onde atende
        elif user.user_type == 'MEDICO' and hasattr(user, 'perfil_medico'):
            clinicas = user.perfil_medico.clinicas.all()
            return Paciente.objects.filter(
                Q(clinica__in=clinicas) |  # Pacientes das clínicas onde atende
                Q(consultas_agendadas__clinica__in=clinicas) |  # Pacientes com consultas nas clínicas
                Q(consultas_agendadas__medico=user)  # Pacientes atendidos pelo médico
            ).distinct()
        
        # Admin: vê todos
        elif user.is_staff or user.is_superuser:
            return Paciente.objects.all()
        
        # Outros: veem nada
        return Paciente.objects.none()

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

        # Verifica se o usuário é do tipo PACIENTE (Corrigido pelo import do User)
        if usuario_logado.user_type != User.UserType.PACIENTE:
            return Response({"erro": "Acesso negado. Esta view é para pacientes."}, status=403)
        
        try:
            paciente = Paciente.objects.get(user=usuario_logado)
        except Paciente.DoesNotExist:
            return Response({"erro": "Perfil de paciente não encontrado."}, status=404)

        nome_paciente = usuario_logado.get_full_name()

        # --- 1. Busca TODAS as consultas futuras (como OBJETOS) ---
        consultas_futuras = Consulta.objects.filter(
            paciente=paciente,
            data_hora__gte=timezone.now()
        ).exclude( # Excluir Canceladas
            status_atual=STATUS_CONSULTA_CANCELADA
        ).select_related(
            'medico__perfil_medico', 'clinica' # 'medico__user' foi removido daqui
        ).order_by('data_hora')

        # 2. A "próxima consulta" é apenas a primeira desta lista
        proxima_consulta = consultas_futuras.first()

        # 3. Contexto para o Serializer
        serializer_context = {'request': request}

        # 4. Serializa a próxima consulta (se existir)
        dados_proxima_consulta = None # Inicialização para evitar o NameError
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