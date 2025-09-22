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
            # Implementação da validação de conflito de horário
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

    def put(self, request, pk):
        consulta = get_object_or_404(self.get_queryset(), pk=pk)
        serializer = ConsultaSerializer(consulta, data=request.data, partial=False)
        if serializer.is_valid(raise_exception=True):
            
            # Validação para evitar conflitos de horário na atualização
            data_hora = serializer.validated_data.get('data_hora', consulta.data_hora)
            medico = serializer.validated_data.get('medico', consulta.medico)

            if Consulta.objects.exclude(pk=pk).filter(medico=medico, data_hora=data_hora).exists():
                return Response(
                    {"error": "Novo horário de consulta conflitua com um agendamento existente."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                with transaction.atomic():
                    # Verificação e registro do status
                    status_anterior = consulta.status_atual
                    updated_consulta = serializer.save()

                    if updated_consulta.status_atual != status_anterior:
                        ConsultaStatusLog.objects.create(
                            consulta=updated_consulta,
                            status_novo=updated_consulta.status_atual,
                            pessoa=self.request.user
                        )

            except Exception as e:
                return Response(
                    {"error": str(e)},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
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
