# notificacoes/views.py

from rest_framework import generics, permissions, status
from rest_framework.response import Response
from .models import Notificacao
from .serializers import NotificacaoSerializer

class ListaNotificacoesView(generics.ListAPIView):
    """
    Lista todas as notificações para o usuário autenticado.
    """
    serializer_class = NotificacaoSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Retorna apenas as notificações do usuário logado
        return Notificacao.objects.filter(usuario=self.request.user)

class MarcarNotificacaoComoLidaView(generics.UpdateAPIView):
    """
    Marca uma notificação específica como lida (via PATCH).
    """
    serializer_class = NotificacaoSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Usuário só pode modificar suas próprias notificações
        return Notificacao.objects.filter(usuario=self.request.user)

    def update(self, request, *args, **kwargs):
        notificacao = self.get_object()
        notificacao.lida = True
        notificacao.save()
        serializer = self.get_serializer(notificacao)
        return Response(serializer.data)