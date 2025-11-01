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
from users.permissions import IsMedicoOrSecretaria, IsMedicoUser
from .consts import STATUS_CONSULTA_CONCLUIDA, STATUS_CONSULTA_PENDENTE, STATUS_CONSULTA_CHOICES
from users.models import User
from pacientes.models import Paciente
from medicos.models import Medico


class ConsultaAPIView(APIView):
    """
    API para gerenciar o CRUD completo de agendamentos.
    Permite que médicos e secretárias realizem todas as operações.
    """
    permission_classes = [IsMedicoOrSecretaria]

    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'MEDICO':
            return Consulta.objects.filter(medico=user).order_by('data_hora')
        elif user.user_type == 'SECRETARIA':
            try:
                clinica = user.perfil_secretaria.clinica 
                return Consulta.objects.filter(clinica=clinica).order_by('data_hora')
            except AttributeError:
                return Consulta.objects.none()
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
            
            if Consulta.objects.filter(medico=medico, data_hora=data_hora).exists():
                return Response(
                    {"error": "Médico já tem uma consulta agendada para este horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
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
                return Response(
                    {"error": str(e)},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )

            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, pk=None):
        if pk is None:
            return Response(
                {"error": "A chave primária (pk) é necessária para esta operação."},
                status=status.HTTP_400_BAD_REQUEST
            )

        consulta = get_object_or_404(self.get_queryset(), pk=pk)
        serializer = ConsultaSerializer(consulta, data=request.data, partial=True)

        if serializer.is_valid(raise_exception=True):
            data_hora_nova = serializer.validated_data.get('data_hora', consulta.data_hora)
            medico = consulta.medico

            if 'data_hora' in serializer.validated_data:
                conflitos = Consulta.objects.filter(
                    medico=medico,
                    data_hora=data_hora_nova
                ).exclude(pk=pk)

                if conflitos.exists():
                    return Response(
                        {"error": "Médico já tem outra consulta agendada para este novo horário."},
                        status=status.HTTP_400_BAD_REQUEST
                    )

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
                return Response(
                    {"error": str(e)},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )

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

        if not novo_status or novo_status not in [choice[0] for choice in Consulta.STATUS_CONSULTA_CHOICES]:
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
    permission_classes = [IsMedicoOrSecretaria]

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
    Recebe POST em /api/agendamentos/paciente-marcar/
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        # 1. Validação do Paciente
        if not request.user.user_type == 'PACIENTE':
            return Response({"error": "Apenas pacientes podem marcar consultas."}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            paciente = Paciente.objects.get(user=request.user)
        except Paciente.DoesNotExist:
            return Response({"error": "Perfil de paciente não encontrado."}, status=status.HTTP_404_NOT_FOUND)

        # 2. Obter dados da request (conforme api_service.dart)
        medico_nome = request.data.get('medico_nome')
        especialidade_nome = request.data.get('especialidade_nome')
        data_hora_str = request.data.get('data_hora')

        if not all([medico_nome, especialidade_nome, data_hora_str]):
            return Response({"error": "Campos 'medico_nome', 'especialidade_nome' e 'data_hora' são obrigatórios."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            # 3. Encontrar o médico pelo nome e especialidade
            # Isso é frágil, pois depende dos nomes exatos do frontend
            
            # Converte o nome da especialidade (Ex: "Cardiologia") para a chave (Ex: "CARDIOLOGIA")
            especialidade_key = None
            for key, value in Medico.EspecialidadeChoices.choices:
                if value.lower() == especialidade_nome.lower():
                    especialidade_key = key
                    break
            
            if not especialidade_key:
                return Response({"error": f"Especialidade '{especialidade_nome}' não encontrada."}, status=status.HTTP_404_NOT_FOUND)

            # Busca Médicos pelo perfil e tipo de usuário
            medicos_possiveis = User.objects.filter(
                user_type='MEDICO',
                perfil_medico__especialidade=especialidade_key
            )

            # Tenta encontrar o nome exato na lista
            medico_user = None
            for m in medicos_possiveis:
                if m.get_full_name().lower() == medico_nome.lower():
                    medico_user = m
                    break
            
            if not medico_user:
                 return Response({"error": f"Médico '{medico_nome}' não encontrado para esta especialidade."}, status=status.HTTP_404_NOT_FOUND)

            # 4. Obter a clínica do médico (PARA A SECRETÁRIA VER)
            perfil = medico_user.perfil_medico
            if not perfil or not perfil.clinica:
                return Response({"error": "Médico não está associado a nenhuma clínica."}, status=status.HTTP_400_BAD_REQUEST)

            # 5. Criar a consulta
            Consulta.objects.create(
                paciente=paciente,
                medico=medico_user,
                clinica=clinica,
                data_hora=data_hora_str,
                status_atual=STATUS_CONSULTA_PENDENTE, # Importado de consts.py
                valor=0.00 # Paciente não define valor, pode ser 0 ou um valor padrão
            )
            
            return Response({"message": "Consulta marcada com sucesso!"}, status=status.HTTP_201_CREATED)

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
