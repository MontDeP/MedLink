# agendamentos/views.py (VERSÃO CORRIGIDA E COMPLETA)

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from datetime import timedelta, datetime
from rest_framework.permissions import IsAuthenticated

from .models import Consulta, Pagamento, ConsultaStatusLog, AnotacaoConsulta
from .serializers import ConsultaSerializer, AnotacaoConsultaSerializer
from users.permissions import IsMedicoOrSecretaria
from .consts import STATUS_CONSULTA_CONCLUIDA, STATUS_CONSULTA_CHOICES, STATUS_CONSULTA_PENDENTE
from users.permissions import IsMedicoUser, HasRole
from clinicas.models import Clinica # <<< Novo import
from medicos.models import Medico
from users.models import User
from datetime import timedelta, datetime, time # <<< CORRIGIDO: 'time' deve estar aqui
from pacientes.models import Paciente # <<< CORREÇÃO APLICADA AQUI
from django.db.models import Q

class ConsultaAPIView(APIView):
    """
    API para gerenciar o CRUD completo de agendamentos.
    Permite que médicos e secretárias realizem todas as operações.
    """
    permission_classes = [IsMedicoOrSecretaria]

    def get_queryset(self):
        user = self.request.user
        # Admin vê tudo
        if getattr(user, 'is_staff', False) or getattr(user, 'is_superuser', False):
            return Consulta.objects.all().order_by('data_hora')
        
        # Secretária: filtra APENAS pela clínica associada
        if getattr(user, 'user_type', None) == 'SECRETARIA':
            try:
                clinica = user.perfil_secretaria.clinica
                return Consulta.objects.filter(clinica=clinica).order_by('data_hora')
            except AttributeError:
                return Consulta.objects.none()
        
        # Médico: filtra por clínicas associadas
        if getattr(user, 'user_type', None) == 'MEDICO':
            medico = getattr(user, 'perfil_medico', None)
            if medico and hasattr(medico, 'clinicas'):
                clinics = medico.clinicas.all()
                if clinics.exists():
                    return Consulta.objects.filter(clinica__in=clinics).order_by('data_hora')
            return Consulta.objects.filter(medico=user).order_by('data_hora')
        
        # Paciente: só suas consultas
        if getattr(user, 'user_type', None) == 'PACIENTE':
            paciente = getattr(user, 'perfil_paciente', None)
            if paciente:
                return Consulta.objects.filter(paciente=paciente).order_by('data_hora')
        
        # fallback: nada
        return Consulta.objects.none()

    def get(self, request, pk=None):
        if pk:
            consulta = get_object_or_404(self.get_queryset(), pk=pk)
            serializer = ConsultaSerializer(consulta)
            return Response(serializer.data)
        
        consultas = self.get_queryset()
        serializer = ConsultaSerializer(consultas, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = ConsultaSerializer(data=request.data)
        if serializer.is_valid(raise_exception=True):
            data_hora = serializer.validated_data['data_hora']
            medico = serializer.validated_data['medico']
            paciente = serializer.validated_data['paciente']

            # --- CORREÇÃO: CONFLITO DISCRETO PARA SLOTS DE 30 MINUTOS ---
            # Checa APENAS se o horário de INÍCIO proposto (data_hora) está ocupado.
            
            # Conflito por médico (Slot Atual)
            conflito_medico = Consulta.objects.filter(
                medico=medico,
                data_hora=data_hora 
            ).exists()
            if conflito_medico:
                return Response(
                    {"error": "O médico já possui consulta no horário proposto."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Conflito por paciente (Slot Atual)
            conflito_paciente = Consulta.objects.filter(
                paciente=paciente,
                data_hora=data_hora
            ).exists()
            if conflito_paciente:
                return Response(
                    {"error": "O paciente já possui consulta neste horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            # --- FIM DA CORREÇÃO ---
            try:
                with transaction.atomic():
                    consulta = serializer.save()
                    Pagamento.objects.create(
                        consulta=consulta,
                        status='PENDENTE',
                        valor_pago=consulta.valor,
                    )
                    ConsultaStatusLog.objects.create(
                        consulta=consulta,
                        status_novo=consulta.status_atual,
                        pessoa=self.request.user
                    )
            except Exception as e:
                return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, pk=None):
        if pk is None:
            return Response({"error": "A chave primária (pk) é necessária para esta operação."},
                            status=status.HTTP_400_BAD_REQUEST)

        consulta = get_object_or_404(self.get_queryset(), pk=pk)
        serializer = ConsultaSerializer(consulta, data=request.data, partial=True)

        if serializer.is_valid(raise_exception=True):
            data_hora_nova = serializer.validated_data.get('data_hora', consulta.data_hora)
            medico = serializer.validated_data.get('medico', consulta.medico)
            paciente = serializer.validated_data.get('paciente', consulta.paciente)

            # --- CORREÇÃO: CONFLITO DISCRETO PARA SLOTS DE 30 MINUTOS (Remarcação) ---
            
            # Conflito por médico (Slot Atual)
            conflito_medico = Consulta.objects.filter(
                medico=medico,
                data_hora=data_hora_nova
            ).exclude(pk=pk).exists()
            if conflito_medico:
                return Response(
                    {"error": "O médico já possui consulta no novo horário proposto."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Conflito por paciente (Slot Atual)
            conflito_paciente = Consulta.objects.filter(
                paciente=paciente,
                data_hora=data_hora_nova
            ).exclude(pk=pk).exists()
            if conflito_paciente:
                return Response(
                    {"error": "O paciente já possui consulta neste novo horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            # --- FIM DA CORREÇÃO ---
            
            # ...existing code (salvar atualização e log se status mudar)...
            try:
                with transaction.atomic():
                    status_anterior = consulta.status_atual
                    consulta_atualizada = serializer.save()

                    if consulta_atualizada.status_atual != status_anterior:
                        ConsultaStatusLog.objects.create(
                            consulta=consulta_atualizada,
                            status_novo=consulta_atualizada.status_atual,
                            pessoa=self.request.user
                        )
            except Exception as e:
                return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk=None):
        if pk is None:
            return Response(
                {"error": "A chave primária (pk) é necessária para esta operação."},
                status=status.HTTP_400_BAD_REQUEST
            )
        consulta = get_object_or_404(self.get_queryset(), pk=pk)
        try:
            with transaction.atomic():
                ConsultaStatusLog.objects.create(
                    consulta=consulta,
                    status_novo='CANCELADA',
                    pessoa=self.request.user
                )
                consulta.delete()
        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        return Response(status=status.HTTP_204_NO_CONTENT)

# -----------------------------------------------------------------------------
# Views para a atualização de status e pagamento
# -----------------------------------------------------------------------------

class ConsultaStatusUpdateView(APIView):
    permission_classes = [IsMedicoOrSecretaria]

    def put(self, request, pk):
        consulta = get_object_or_404(Consulta.objects.all(), pk=pk)
        novo_status = request.data.get('status_atual')

        if not novo_status or novo_status not in [choice[0] for choice in STATUS_CONSULTA_CHOICES]:
            return Response(
                {"error": "O campo 'status_atual' com um valor válido é obrigatório."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            with transaction.atomic():
                status_anterior = consulta.status_atual
                if consulta.status_atual != novo_status:
                    consulta.status_atual = novo_status
                    consulta.save()

                    ConsultaStatusLog.objects.create(
                        consulta=consulta,
                        status_novo=consulta.status_atual,
                        pessoa=self.request.user
                    )
                
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        serializer = ConsultaSerializer(consulta)
        return Response(serializer.data, status=status.HTTP_200_OK)


class PagamentoUpdateView(APIView):
    permission_classes = [HasRole]
    required_roles = ['SECRETARIA']

    def put(self, request, pk):
        consulta = get_object_or_404(Consulta.objects.all(), pk=pk)
        pagamento = get_object_or_404(Pagamento.objects.all(), consulta=consulta)

        if pagamento.status == 'PAGO':
            return Response(
                {"message": "O pagamento já foi processado."},
                status=status.HTTP_200_OK
            )
        
        try:
            with transaction.atomic():
                pagamento.status = 'PAGO'
                pagamento.data_pagamento = timezone.now()
                pagamento.save()
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        serializer = ConsultaSerializer(consulta)
        return Response(serializer.data, status=status.HTTP_200_OK)

# --- VIEW PARA ANOTAÇÕES (ADICIONADA NA RESPOSTA ANTERIOR) ---
class AnotacaoConsultaView(APIView):
    """
    View para obter, criar ou atualizar a anotação de uma consulta específica.
    """
    permission_classes = [IsMedicoOrSecretaria]

    def get(self, request, pk, *args, **kwargs):
        anotacao = get_object_or_404(AnotacaoConsulta, pk=pk)
        serializer = AnotacaoConsultaSerializer(anotacao)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, pk, *args, **kwargs):
        consulta = get_object_or_404(Consulta, pk=pk)
        conteudo = request.data.get('conteudo', '')

        anotacao, created = AnotacaoConsulta.objects.update_or_create(
            consulta=consulta,
            defaults={'conteudo': conteudo}
        )
        serializer = AnotacaoConsultaSerializer(anotacao)
        status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(serializer.data, status=status_code)
    
# ADICIONE ESTA NOVA CLASSE AO FINAL DO ARQUIVO
class FinalizarConsultaAPIView(APIView):
    """
    Endpoint para um médico finalizar uma consulta.
    Muda o status para 'CONCLUIDA' e salva a anotação final.
    """
    permission_classes = [IsMedicoUser]

    def post(self, request, pk, *args, **kwargs):
        consulta = get_object_or_404(Consulta, pk=pk, medico=request.user)
        conteudo_anotacao = request.data.get('conteudo', '')

        try:
            with transaction.atomic():
                # 1. Salva ou atualiza a anotação
                AnotacaoConsulta.objects.update_or_create(
                    consulta=consulta,
                    defaults={'conteudo': conteudo_anotacao}
                )

                # 2. Atualiza o status da consulta
                if consulta.status_atual != STATUS_CONSULTA_CONCLUIDA:
                    status_anterior = consulta.status_atual
                    consulta.status_atual = STATUS_CONSULTA_CONCLUIDA
                    consulta.save()

                    # 3. Cria um log da mudança de status
                    ConsultaStatusLog.objects.create(
                        consulta=consulta,
                        status_novo=STATUS_CONSULTA_CONCLUIDA,
                        pessoa=request.user
                    )
            
            serializer = ConsultaSerializer(consulta)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            return Response(
                {"error": f"Ocorreu um erro ao finalizar a consulta: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class PacienteMarcarConsultaView(APIView):
    """
    Endpoint para o PACIENTE logado marcar uma nova consulta.
    NOVO: Recebe 'medico_id', 'clinica_id' e 'data_hora'.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        # 1. Validação do Paciente e dados
        if not request.user.user_type == 'PACIENTE':
            return Response({"error": "Apenas pacientes podem marcar consultas."}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            paciente = Paciente.objects.get(user=request.user)
        except Paciente.DoesNotExist:
            return Response({"error": "Perfil de paciente não encontrado."}, status=status.HTTP_404_NOT_FOUND)

        medico_id = request.data.get('medico_id')
        clinica_id = request.data.get('clinica_id')
        data_hora_str = request.data.get('data_hora')

        if not all([medico_id, clinica_id, data_hora_str]):
            return Response({"error": "Campos 'medico_id', 'clinica_id' e 'data_hora' são obrigatórios."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            medico_user = User.objects.get(pk=medico_id, user_type='MEDICO')
            clinica = Clinica.objects.get(pk=clinica_id)
            
            # --- INÍCIO DA CORREÇÃO DE FUSO HORÁRIO (USE_TZ=False) ---
            data_hora = datetime.fromisoformat(data_hora_str)
            if timezone.is_aware(data_hora):
                data_hora = timezone.make_naive(data_hora)
            # --- FIM DA CORREÇÃO DE FUSO HORÁRIO ---

            # --- CORREÇÃO: CONFLITO DISCRETO (Slot Atual) ---
            
            # Conflito por médico (Slot Atual)
            conflito_medico = Consulta.objects.filter(
                medico=medico_user,
                data_hora=data_hora
            ).exists()
            if conflito_medico:
                return Response(
                    {"error": "O médico já possui consulta no horário proposto."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Conflito por paciente (Slot Atual)
            conflito_paciente = Consulta.objects.filter(
                paciente=paciente,
                data_hora=data_hora
            ).exists()
            if conflito_paciente:
                return Response(
                    {"error": "O paciente já possui consulta neste horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            # --- FIM DA CORREÇÃO ---
            
            # 5. Cria a consulta
            Consulta.objects.create(
                paciente=paciente,
                medico=medico_user,
                clinica=clinica,
                data_hora=data_hora,
                status_atual=STATUS_CONSULTA_PENDENTE,
                valor=0.00
            )
            
            return Response({"message": "Consulta marcada com sucesso!"}, status=status.HTTP_201_CREATED)

        except (User.DoesNotExist, Clinica.DoesNotExist):
            return Response({"error": "Médico ou clínica não encontrados."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({"error": f"Erro ao processar a marcação: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PacienteRemarcarConsultaView(APIView):
    """
    Endpoint para o PACIENTE logado remarcar uma consulta.
    Recebe PATCH em /api/agendamentos/<int:pk>/paciente-remarcar/
    """
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk, *args, **kwargs):
        try:
            # 1. Verifica se o usuário é paciente
            if not request.user.user_type == 'PACIENTE':
                return Response(
                    {"error": "Apenas pacientes podem remarcar consultas."},
                    status=status.HTTP_403_FORBIDDEN
                )

            # 2. Busca a consulta
            consulta = get_object_or_404(Consulta, pk=pk)

            if consulta.paciente.user != request.user:
                return Response(
                    {"error": "Você não tem permissão para alterar esta consulta."},
                    status=status.HTTP_403_FORBIDDEN
                )

            # 3. Nova data
            data_hora_nova_str = request.data.get('data_hora')
            if not data_hora_nova_str:
                return Response(
                    {"error": "O campo 'data_hora' é obrigatório."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                data_hora_nova = datetime.fromisoformat(data_hora_nova_str)
                if timezone.is_naive(data_hora_nova):
                    data_hora_nova = timezone.make_aware(data_hora_nova)
            except ValueError:
                return Response(
                    {"error": "Formato de data/hora inválido. Use o padrão ISO 8601 (YYYY-MM-DDTHH:MM:SS)."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # 4. Validação: só pode remarcar com pelo menos 3 dias de antecedência
            data_consulta_aware = consulta.data_hora
            if timezone.is_naive(data_consulta_aware):
                data_consulta_aware = timezone.make_aware(data_consulta_aware)

            if (data_consulta_aware - timezone.now()).days < 3:
                return Response(
                    {"error": "Não é possível remarcar com menos de 3 dias de antecedência."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # 5. Atualiza e salva
            consulta.data_hora = data_hora_nova
            if 'REAGENDADA' in [choice[0] for choice in STATUS_CONSULTA_CHOICES]:
                consulta.status_atual = 'REAGENDADA'
            else:
                consulta.status_atual = STATUS_CONSULTA_PENDENTE

            consulta.save()

            # 6. Log
            ConsultaStatusLog.objects.create(
                consulta=consulta,
                status_novo=consulta.status_atual,
                pessoa=request.user
            )

            return Response({"message": "Consulta remarcada com sucesso!"}, status=status.HTTP_200_OK)

        except Exception as e:
            return Response(
                {"error": f"Erro interno ao salvar a remarcação: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ClinicaListView(APIView):
    """Retorna todas as clínicas ativas para seleção de agendamento."""
    permission_classes = [IsAuthenticated] 

    def get(self, request):
        clinicas = Clinica.objects.all().values('pk', 'nome_fantasia')
        data = [{'id': c['pk'], 'nome': c['nome_fantasia']} for c in clinicas]
        return Response(data, status=status.HTTP_200_OK)

class ClinicaEspecialidadeListView(APIView):
    """Retorna as especialidades distintas dos médicos vinculados a uma clínica."""
    permission_classes = [IsAuthenticated]

    def get(self, request, clinica_pk):
        medicos_na_clinica = Medico.objects.filter(clinicas__pk=clinica_pk).distinct()
        especialidade_keys = medicos_na_clinica.values_list('especialidade', flat=True).distinct()
        
        especialidades = []
        for key in especialidade_keys:
            # Converte a chave (CARDIOLOGIA) para o nome de exibição (Cardiologia)
            display_name = Medico.EspecialidadeChoices(key).label 
            especialidades.append({'key': key, 'nome': display_name})
            
        return Response(especialidades, status=status.HTTP_200_OK)

class EspecialidadeMedicoListView(APIView):
    """Retorna os médicos ativos em uma clínica e com uma especialidade específica."""
    permission_classes = [IsAuthenticated]

    def get(self, request, clinica_pk, especialidade_key):
        medicos = Medico.objects.filter(
            clinicas__pk=clinica_pk, 
            especialidade=especialidade_key, 
            user__is_active=True 
        ).select_related('user').order_by('user__first_name')
        
        data = []
        for medico in medicos:
            data.append({
                'id': medico.user.id, 
                'nome': medico.user.get_full_name(),
                'crm': medico.crm,
                'especialidade': medico.get_especialidade_display(), 
            })
            
        return Response(data, status=status.HTTP_200_OK)

class MedicoHorariosDisponiveisView(APIView):
    """
    Retorna os horários de 30 em 30 minutos em que o médico não tem conflito 
    de consulta para a data fornecida. (Reutiliza lógica da secretaria)
    """
    permission_classes = [IsAuthenticated]
    INTERVALO_MINUTOS = 30
    HORA_INICIO_PADRAO = 8
    HORA_FIM_PADRAO = 20 # <<< CORRIGIDO PARA 20 (8 PM)
    ALMOCO_INICIO = 12
    ALMOCO_FIM = 13

    def get(self, request, medico_pk):
        # ... (restante do código da função)
        try:
            medico = User.objects.get(pk=medico_pk, user_type='MEDICO')
        except User.DoesNotExist:
            return Response({"error": "Médico não encontrado."}, status=status.HTTP_404_NOT_FOUND)

        data_str = request.query_params.get('data')
        
        if not data_str:
            # Retorno simplificado para guiar o paciente no calendário (opcional)
            hoje = timezone.now().date()
            proximo_dia_util = hoje + timedelta(days=1)
            while proximo_dia_util.weekday() >= 5: 
                proximo_dia_util += timedelta(days=1)
            datas_sugeridas = [(proximo_dia_util + timedelta(days=i)).strftime('%Y-%m-%d') for i in range(7)]
            return Response({'datas_sugeridas': datas_sugeridas}, status=status.HTTP_200_OK)

        try:
            data_alvo = datetime.strptime(data_str, '%Y-%m-%d').date()
        except ValueError:
            return Response({"error": "Formato de data inválido. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)

        # Horários ocupados (lógica de conflito de 30 minutos)
        consultas_ocupadas = Consulta.objects.filter(
            medico=medico,
            data_hora__date=data_alvo
        ).values_list('data_hora', flat=True)
        
        ocupados = set()
        for dh in consultas_ocupadas:
            inicio_naive = timezone.make_naive(dh) if timezone.is_aware(dh) else dh
            ocupados.add(inicio_naive.time())
            # Slots de 30 min antes e depois do início de uma consulta existente também são bloqueados
            # A checagem de conflito discreto (abaixo) garante que apenas o slot anterior seja bloqueado
            # se estiver sendo usado, mas aqui no horário disponível, usamos o slot
            # e não o anterior. A verificação do slot anterior é feita no POST.
        
        # Gera todos os slots
        slots_disponiveis = []
        hora = self.HORA_INICIO_PADRAO
        minuto = 0
        while hora < self.HORA_FIM_PADRAO or (hora == self.HORA_FIM_PADRAO and minuto == 0):
            slot_time = time(hour=hora, minute=minuto)
            
            # Pula o horário de almoço (12:00 a 12:59)
            if not (self.ALMOCO_INICIO <= hora < self.ALMOCO_FIM):
                 # Checa se este slot está na lista de horários de início de consultas existentes
                 if slot_time not in [timezone.make_naive(dh).time() if timezone.is_aware(dh) else dh.time() for dh in consultas_ocupadas]:
                    slots_disponiveis.append(slot_time.strftime('%H:%M'))

            minuto += self.INTERVALO_MINUTOS
            if minuto >= 60:
                hora += 1
                minuto -= 60

        return Response(slots_disponiveis, status=status.HTTP_200_OK)