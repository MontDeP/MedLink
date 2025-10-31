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
from django.db.models import Q

# View para CRIAR pacientes (sem alterações)
class PacienteCreateView(generics.CreateAPIView):
    queryset = Paciente.objects.all()
    serializer_class = PacienteCreateSerializer
    permission_classes = [AllowAny]

    def perform_create(self, serializer):
        # Cria o paciente normalmente
        paciente = serializer.save()
        # Se for secretária ou médico autenticado, seta a clínica automaticamente
        user = getattr(self.request, 'user', None)
        if user and user.is_authenticated:
            # Secretária: usa a clínica da secretária
            if getattr(user, 'user_type', None) == 'SECRETARIA' and hasattr(user, 'perfil_secretaria'):
                clinica = getattr(user.perfil_secretaria, 'clinica', None)
                if clinica:
                    paciente.clinica = clinica
                    paciente.save()
            # Médico: usa uma das clínicas do médico (primeira da lista)
            elif getattr(user, 'user_type', None) == 'MEDICO' and hasattr(user, 'perfil_medico'):
                clinicas = getattr(user.perfil_medico, 'clinicas', None)
                if clinicas:
                    primeira_clinica = clinicas.first()
                    if primeira_clinica:
                        paciente.clinica = primeira_clinica
                        paciente.save()

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