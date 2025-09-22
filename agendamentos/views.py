from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from .models import Consulta, Pagamento, ConsultaStatusLog
from .serializers import ConsultaSerializer
from users.permissions import IsMedicoOrSecretaria
from datetime import timedelta

class ConsultaAPIView(APIView):
    """
    API para gerenciar o CRUD completo de agendamentos.
    Permite que médicos e secretárias realizem todas as operações.
    """
    permission_classes = [IsMedicoOrSecretaria]

    def get_queryset(self):
        """
        Retorna as consultas da clínica do usuário logado.
        """
        user = self.request.user
        # Lembrete: Implemente os modelos 'Medico' e 'Secretaria' para evitar este 'try/except'
        if user.user_type == 'MEDICO':
            # Filtra consultas do médico logado
            return Consulta.objects.filter(medico=user).order_by('data_hora')
        elif user.user_type == 'SECRETARIA':
            # Filtra consultas da clínica da secretária logada
            try:
                # Supondo que o modelo Secretaria tenha uma FK para Clinica
                clinica = user.secretaria_perfil.clinica 
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
            # Implementação da validação de conflito de horário (Regra de Negócio 1)
            data_hora = serializer.validated_data['data_hora']
            medico = serializer.validated_data['medico']
            
            if Consulta.objects.filter(medico=medico, data_hora=data_hora).exists():
                return Response(
                    {"error": "Médico já tem uma consulta agendada para este horário."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            try:
                # Transação atômica para garantir a integridade dos dados (Regra de Negócio 2)
                with transaction.atomic():
                    # Salva a nova consulta
                    consulta = serializer.save()
                    
                    # Cria um registro de pagamento com status inicial PENDENTE
                    Pagamento.objects.create(
                        consulta=consulta,
                        status='PENDENTE',
                        valor_pago=consulta.valor, # O valor do pagamento é o mesmo da consulta
                    )

                    # Cria um registro de log para a criação da consulta (Regra de Negócio 3)
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

            headers = self.get_success_headers(serializer.data)
            return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
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
                # Antes de deletar, registramos o log de cancelamento
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
# Views para a atualização de status e pagamento (delegando a lógica)
# -----------------------------------------------------------------------------

class ConsultaStatusUpdateView(APIView):
    """
    API para atualizar o status de uma consulta.
    """
    permission_classes = [IsMedicoOrSecretaria]

    def put(self, request, pk):
        consulta = get_object_or_404(Consulta.objects.all(), pk=pk)
        novo_status = request.data.get('status_atual')

        if not novo_status or novo_status not in [choice[0] for choice in consulta.STATUS_CHOICES]:
            return Response(
                {"error": "O campo 'status_atual' com um valor válido é obrigatório."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            with transaction.atomic():
                status_anterior = consulta.status_atual
                consulta.status_atual = novo_status
                consulta.save()

                if consulta.status_atual != status_anterior:
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
    """
    API para marcar o pagamento de uma consulta como concluído.
    """
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

                # Opcional: Atualizar o status da consulta para 'CONCLUIDA' automaticamente
                if consulta.status_atual != 'CONCLUIDA':
                    consulta.status_atual = 'CONCLUIDA'
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