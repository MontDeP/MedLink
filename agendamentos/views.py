# agendamentos/views.py (VERSÃO CORRIGIDA E COMPLETA)

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from datetime import timedelta

# --- CORREÇÃO: ADICIONADAS AS IMPORTAÇÕES QUE FALTAVAM ---
from .models import Consulta, Pagamento, ConsultaStatusLog, AnotacaoConsulta
from .serializers import ConsultaSerializer, AnotacaoConsultaSerializer
from users.permissions import IsMedicoOrSecretaria
from .consts import STATUS_CONSULTA_CONCLUIDA
from users.permissions import IsMedicoUser


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