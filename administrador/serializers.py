# administrador/serializers.py
from rest_framework import serializers
from users.models import User
from .models import LogEntry

class AdminUserSerializer(serializers.ModelSerializer):
    """
    Serializer para a listagem (READ) de utilizadores no painel de administração.
    Mostra os dados de forma legível.
    """
    user_type_display = serializers.CharField(source='get_user_type_display', read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'first_name', 'last_name', 'email', 'cpf', 
            'user_type', 'user_type_display', 'is_active', 'last_login'
        ]

class AdminUserCreateUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer para a criação (CREATE) e atualização (UPDATE) de utilizadores.
    """
    class Meta:
        model = User
        fields = [
            'first_name', 'last_name', 'email', 'cpf', 
            'user_type', 'is_active',
            'password'
        ]
        
        # A senha agora é write_only e NÃO obrigatória.
        extra_kwargs = {
            # 'required': False garante que não é obrigatório no payload
            # 'allow_null': True é uma boa prática se você for enviar 'null'
            'password': {'write_only': True, 'required': False, 'allow_null': True}
        }

    def create(self, validated_data):
        
        cpf = validated_data.pop('cpf')
        email = validated_data.pop('email')
        
        # Pega a senha, ou None se não for fornecida (graças ao 'required=False')
        password = validated_data.pop('password', None)
        
        # O que sobrou em 'validated_data' (first_name, last_name, etc.)
        # será passado como **extra_fields
        user = User.objects.create_user(
            cpf=cpf,
            email=email,
            password=password,
            **validated_data
        )
        return user

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        user = super().update(instance, validated_data)

        if password:
            user.set_password(password)
            user.save()
            
        return user
    
class LogEntrySerializer(serializers.ModelSerializer):
    """
    Serializer para o modelo de LogEntry.
    """
    actor_name = serializers.CharField(source='actor.get_full_name', read_only=True)
    action_display = serializers.CharField(source='get_action_type_display', read_only=True)

    class Meta:
        model = LogEntry
        fields = ['id', 'timestamp', 'actor', 'actor_name', 'action_type', 'action_display', 'details']