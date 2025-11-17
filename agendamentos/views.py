# agendamentos/views.py (VERSÃO CORRIGIDA E COMPLETA)

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from datetime import datetime, timedelta
from rest_framework.permissions import IsAuthenticated
from rest_framework import permissions
from clinicas.models import Clinica
from users.models import User
from .models import Consulta, Pagamento, ConsultaStatusLog, AnotacaoConsulta
from .serializers import ConsultaSerializer, AnotacaoConsultaSerializer
from users.permissions import IsMedicoOrSecretaria
from .consts import STATUS_CONSULTA_CONCLUIDA, STATUS_CONSULTA_CHOICES, STATUS_CONSULTA_PENDENTE, STATUS_PAGAMENTO_PENDENTE, STATUS_CONSULTA_CONFIRMADA, STATUS_CONSULTA_CANCELADA
from users.permissions import IsMedicoUser, HasRole



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

            # --- JANELA MÍNIMA DE 30 MINUTOS ---
            janela_inicio = data_hora - timedelta(minutes=30)
            janela_fim = data_hora + timedelta(minutes=30)

            # Conflito por médico (qualquer consulta no intervalo)
            conflito_medico = Consulta.objects.filter(
                medico=medico,
                data_hora__gte=janela_inicio,
                data_hora__lt=janela_fim,
            ).exists()
            if conflito_medico:
                return Response(
                    {"error": "O médico já possui consulta em uma janela de 30 minutos neste horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Conflito por paciente (qualquer consulta no intervalo)
            conflito_paciente = Consulta.objects.filter(
                paciente=paciente,
                data_hora__gte=janela_inicio,
                data_hora__lt=janela_fim,
            ).exists()
            if conflito_paciente:
                return Response(
                    {"error": "O paciente já possui consulta em uma janela de 30 minutos neste horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ...existing code (criar consulta, pagamento e log)...
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

            # --- JANELA MÍNIMA DE 30 MINUTOS PARA REMARCAÇÃO ---
            janela_inicio = data_hora_nova - timedelta(minutes=30)
            janela_fim = data_hora_nova + timedelta(minutes=30)

            # Conflito por médico (exclui a própria consulta)
            conflito_medico = Consulta.objects.filter(
                medico=medico,
                data_hora__gte=janela_inicio,
                data_hora__lt=janela_fim,
            ).exclude(pk=pk).exists()
            if conflito_medico:
                return Response(
                    {"error": "O médico já possui consulta em uma janela de 30 minutos neste novo horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Conflito por paciente (exclui a própria consulta)
            conflito_paciente = Consulta.objects.filter(
                paciente=paciente,
                data_hora__gte=janela_inicio,
                data_hora__lt=janela_fim,
            ).exclude(pk=pk).exists()
            if conflito_paciente:
                return Response(
                    {"error": "O paciente já possui consulta em uma janela de 30 minutos neste novo horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )

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


# Em agendamentos/views.py
# (Imports no topo do seu arquivo)
from django.db import transaction
from django.utils import timezone
from datetime import datetime, timedelta
from .consts import STATUS_CONSULTA_PENDENTE
# ...outros imports...

# ... (Suas outras classes) ...

class PacienteMarcarConsultaView(APIView):
    """
    Endpoint para um paciente logado marcar uma nova consulta.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        
        # --- NOSSO TESTE ESTÁ AQUI ---
        print("--- EXECUTANDO A NOVA VIEW (VERSÃO 11:26) ---")
        # -----------------------------------

        data = request.data

        try:
            # 1. PEGA O PACIENTE LOGADO
            paciente = getattr(request.user, 'perfil_paciente', None)
            if paciente is None:
                paciente = getattr(request.user, 'paciente', None)
            
            if paciente is None:
                print("--- FALHA: Usuário não tem perfil de paciente ---")
                return Response({"error": "Usuário logado não possui um perfil de paciente."}, status=status.HTTP_403_FORBIDDEN)

            # 2. RECEBE IDs DO REQUEST
            clinica_id = data.get('clinica_id')
            medico_id = data.get('medico_id')
            data_hora_iso = data.get('data_hora')

            # 3. VALIDAÇÃO BÁSICA
            if not all([clinica_id, medico_id, data_hora_iso]):
                print("--- FALHA: Dados obrigatórios faltando ---")
                return Response({"error": "clinica_id, medico_id e data_hora são obrigatórios."}, status=status.HTTP_400_BAD_REQUEST)

            # 4. BUSCA OS OBJETOS
            print(f"--- Buscando Clinica={clinica_id}, Medico={medico_id} ---")
            clinica = Clinica.objects.get(id=clinica_id)
            medico_user = User.objects.get(id=medico_id)
            data_hora = datetime.fromisoformat(data_hora_iso)

            # 5. VALIDAR REGRAS DE NEGÓCIO
            if not medico_user.perfil_medico.clinicas.filter(id=clinica.id).exists():
                print("--- FALHA: Médico não atende na clínica ---")
                return Response({"error": "Este médico não atende na clínica selecionada."}, status=status.HTTP_400_BAD_REQUEST)

            # 6. VERIFICAÇÃO DE CONFLITO DE HORÁRIO
            print("--- Verificando conflitos de horário ---")
            janela_inicio = data_hora - timedelta(minutes=30)
            janela_fim = data_hora + timedelta(minutes=30)

            conflito_medico = Consulta.objects.filter(
                medico=medico_user, data_hora__gte=janela_inicio, data_hora__lt=janela_fim
            ).exists()
            if conflito_medico:
                print("--- FALHA: Conflito de médico ---")
                return Response({"error": "O médico já possui consulta em uma janela de 30 minutos neste horário."}, status=status.HTTP_400_BAD_REQUEST)

            conflito_paciente = Consulta.objects.filter(
                paciente=paciente, data_hora__gte=janela_inicio, data_hora__lt=janela_fim
            ).exists()
            if conflito_paciente:
                print("--- FALHA: Conflito de paciente ---")
                return Response({"error": "Você já possui consulta em uma janela de 30 minutos neste horário."}, status=status.HTTP_400_BAD_REQUEST)

            # 7. BUSCA O VALOR NO SERVIDOR
            try:
                valor_da_consulta = medico_user.perfil_medico.valor_consulta
            except AttributeError:
                print("--- FALHA: Não foi possível ler o valor da consulta ---")
                return Response({"error": "Não foi possível determinar o valor da consulta para este médico."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            # 8. CRIA A CONSULTA E O PAGAMENTO
            print("--- Criando consulta no banco de dados ---")
            with transaction.atomic():
                consulta = Consulta.objects.create(
                    data_hora=data_hora, paciente=paciente, medico=medico_user,
                    clinica=clinica, valor=valor_da_consulta, status_atual=STATUS_CONSULTA_PENDENTE 
                )
                Pagamento.objects.create(
                    consulta=consulta, status='PENDENTE', valor_pago=consulta.valor,
                )
                ConsultaStatusLog.objects.create(
                    consulta=consulta, status_novo=consulta.status_atual, pessoa=request.user
                )

                # 9. ATUALIZA A CLÍNICA DO PACIENTE
                if paciente.clinica is None:
                    print("--- Atualizando clínica do paciente ---")
                    paciente.clinica = clinica
                    paciente.save()

            print("--- SUCESSO: Consulta criada ---")
            serializer = ConsultaSerializer(consulta)
            return Response(serializer.data, status=status.HTTP_201_CREATED)

        # 10. BLOCOS 'EXCEPT' (GARANTEM O 'RETURN')
        except Clinica.DoesNotExist:
            print("--- FALHA GERAL: Clínica não existe ---")
            return Response({"error": "Clínica não encontrada."}, status=status.HTTP_404_NOT_FOUND)
        except User.DoesNotExist:
            print("--- FALHA GERAL: Médico não existe ---")
            return Response({"error": "Médico não encontrado."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            # Garante que qualquer outro erro retorne uma Resposta
            print(f"--- ERRO INESPERADO: {str(e)} ---")
            return Response({"error": f"Erro interno ao marcar consulta: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



class PacienteRemarcarConsultaView(APIView):
    """
    Endpoint para um paciente remarcar uma consulta existente.
    Permite apenas a alteração da data_hora, aplicando regras de negócio.
    """
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk): # 'pk' é o ID da consulta
        try:
            # Garante que o usuário logado é um paciente
            paciente = request.user.paciente
        except AttributeError:
             return Response({"error": "Apenas pacientes podem remarcar consultas."}, status=status.HTTP_403_FORBIDDEN)

        try:
            # Busca a consulta pelo ID E garante que ela pertence ao paciente logado
            # Usamos select_related para "puxar" o pagamento junto na mesma query
            consulta = get_object_or_404(Consulta.objects.select_related('pagamento'), pk=pk, paciente=paciente)

            nova_data_hora_iso = request.data.get('data_hora')
            if not nova_data_hora_iso:
                return Response({"error": "O campo 'data_hora' é obrigatório."}, status=status.HTTP_400_BAD_REQUEST)

            nova_data_hora = datetime.fromisoformat(nova_data_hora_iso)
            
            # --- INÍCIO DAS REGRAS DE NEGÓCIO ---

            agora = timezone.now()

            # REGRA 1: Não pode remarcar com menos de 24h
            if (consulta.data_hora - agora) < timedelta(hours=24):
                return Response(
                    {"error": "Não é possível remarcar consultas com menos de 24 horas de antecedência. Por favor, entre em contato com a clínica."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # REGRA 2: Não pode remarcar se já estiver PAGO
            # (Usamos o 'pagamento' que buscamos com select_related)
            if consulta.pagamento.status != STATUS_PAGAMENTO_PENDENTE:
                return Response(
                    {"error": "Não é possível remarcar uma consulta que já foi paga. Por favor, entre em contato com a clínica."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # REGRA 3: Limite de 2 remarcações
            # (Usamos o campo novo do models.py)
            if consulta.remarcacoes_paciente >= 2:
                return Response(
                    {"error": "Você atingiu o limite de remarcações (2) para esta consulta. Por favor, entre em contato com a clínica."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # REGRA 4: Não pode remarcar se já passou ou foi cancelada
            if consulta.status_atual in [STATUS_CONSULTA_CONCLUIDA, 'CANCELADA']:
                 return Response(
                    {"error": f"Não é possível remarcar uma consulta com status '{consulta.status_atual}'."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # --- VERIFICAÇÃO DE CONFLITO (Lógica que já existia) ---
            janela_inicio = nova_data_hora - timedelta(minutes=30)
            janela_fim = nova_data_hora + timedelta(minutes=30)

            conflito_medico = Consulta.objects.filter(
                medico=consulta.medico,
                data_hora__gte=janela_inicio,
                data_hora__lt=janela_fim,
            ).exclude(pk=pk).exists()
            if conflito_medico:
                return Response(
                    {"error": "O médico já possui consulta em uma janela de 30 minutos neste novo horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            conflito_paciente = Consulta.objects.filter(
                paciente=paciente,
                data_hora__gte=janela_inicio,
                data_hora__lt=janela_fim,
            ).exclude(pk=pk).exists()
            if conflito_paciente:
                return Response(
                    {"error": "Você já possui consulta em uma janela de 30 minutos neste novo horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            # --- FIM DA VERIFICAÇÃO DE CONFLITO ---

            with transaction.atomic():
                # Atualiza a consulta
                consulta.data_hora = nova_data_hora
                consulta.status_atual = STATUS_CONSULTA_PENDENTE # Volta para pendente
                consulta.remarcacoes_paciente += 1 # <-- INCREMENTA O CONTADOR
                consulta.save()

                # Cria o log da remarcação
                ConsultaStatusLog.objects.create(
                    consulta=consulta,
                    status_novo=STATUS_CONSULTA_PENDENTE,
                    pessoa=request.user,
                    # Adicionamos uma observação para clareza no admin
                    # (Precisa adicionar o campo 'observacao' no modelo ConsultaStatusLog se não existir)
                    # observacao="Consulta remarcada pelo paciente." 
                )

            serializer = ConsultaSerializer(consulta)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Consulta.DoesNotExist:
            return Response({"error": "Consulta não encontrada ou não pertence a você."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
# agendamentos/views.py

# ... (Depois da classe PacienteRemarcarConsultaView) ...

class PacienteCancelarConsultaView(APIView):
    """
    Endpoint para um paciente cancelar uma consulta pendente ou confirmada.
    """
    permission_classes = [permissions.IsAuthenticated]

    # Usamos PATCH por ser uma atualização de status
    def patch(self, request, pk):
        try:
            paciente = request.user.paciente
        except AttributeError:
             return Response({"error": "Apenas pacientes podem cancelar consultas."}, status=status.HTTP_403_FORBIDDEN)

        try:
            # Busca a consulta e o pagamento relacionado
            consulta = get_object_or_404(Consulta.objects.select_related('pagamento'), pk=pk, paciente=paciente)

            agora = timezone.now()

            # --- INÍCIO DAS REGRAS DE NEGÓCIO ---

            # REGRA 1: Não pode cancelar com menos de 24h
            if (consulta.data_hora - agora) < timedelta(hours=24):
                return Response(
                    {"error": "Não é possível cancelar consultas com menos de 24 horas de antecedência. Por favor, entre em contato com a clínica."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # REGRA 2: Não pode cancelar se já estiver PAGO
            if consulta.pagamento.status != STATUS_PAGAMENTO_PENDENTE:
                return Response(
                    {"error": "Não é possível cancelar uma consulta que já foi paga. Por favor, entre em contato com a clínica."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # REGRA 3: Só pode cancelar se estiver PENDENTE ou CONFIRMADA
            if consulta.status_atual not in [STATUS_CONSULTA_PENDENTE, STATUS_CONSULTA_CONFIRMADA]:
                 return Response(
                    {"error": f"Não é possível cancelar uma consulta com status '{consulta.status_atual}'."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # --- FIM DAS REGRAS ---

            with transaction.atomic():
                # Atualiza o status
                consulta.status_atual = STATUS_CONSULTA_CANCELADA
                consulta.save()

                # Cria o log
                ConsultaStatusLog.objects.create(
                    consulta=consulta,
                    status_novo=STATUS_CONSULTA_CANCELADA,
                    pessoa=request.user,
                    # (Opcional) Adicione um campo 'observacao' no seu modelo Log
                    # observacao="Consulta cancelada pelo paciente."
                )

            serializer = ConsultaSerializer(consulta)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Consulta.DoesNotExist:
            return Response({"error": "Consulta não encontrada ou não pertence a você."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)