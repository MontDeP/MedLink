# notificacoes/serializers.py

from rest_framework import serializers
from .models import Notificacao

class NotificacaoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notificacao
        fields = ['id', 'titulo', 'mensagem', 'tipo', 'lida', 'data_criacao']
        read_only_fields = fields # A API de lista é só leitura