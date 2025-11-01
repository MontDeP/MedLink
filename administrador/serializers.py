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
    # Novos campos para o front filtrar/exibir por clínica
    clinica_id = serializers.SerializerMethodField(read_only=True)
    clinica_ids = serializers.SerializerMethodField(read_only=True)
    crm = serializers.SerializerMethodField(read_only=True)         # novo
    specialty = serializers.SerializerMethodField(read_only=True)   # novo

    class Meta:
        model = User
        fields = [
            'id', 'first_name', 'last_name', 'email', 'cpf', 
            'user_type', 'user_type_display', 'is_active', 'last_login',
            'date_joined',  # incluído para o front
            'clinica_id', 'clinica_ids',  # novos
            'crm', 'specialty',  # novos
        ]

    def get_clinica_id(self, obj):
        try:
            if obj.user_type == 'SECRETARIA' and hasattr(obj, 'perfil_secretaria'):
                return getattr(obj.perfil_secretaria, 'clinica_id', None)
            if obj.user_type == 'PACIENTE' and hasattr(obj, 'paciente'):
                return getattr(obj.paciente, 'clinica_id', None)
            if obj.user_type == 'ADMIN' and hasattr(obj, 'perfil_admin'):
                return getattr(obj.perfil_admin, 'clinica_id', None)
        except Exception:
            return None
        return None

    def get_clinica_ids(self, obj):
        try:
            if obj.user_type == 'MEDICO' and hasattr(obj, 'perfil_medico'):
                return list(obj.perfil_medico.clinicas.values_list('id', flat=True))
        except Exception:
            return []
        return []

    def get_crm(self, obj):
        try:
            if obj.user_type == 'MEDICO' and hasattr(obj, 'perfil_medico'):
                return obj.perfil_medico.crm
        except Exception:
            return None
        return None

    def get_specialty(self, obj):
        try:
            if obj.user_type == 'MEDICO' and hasattr(obj, 'perfil_medico'):
                # Ajuste conforme seu model (string ou choices)
                return getattr(obj.perfil_medico, 'especialidade', None)
        except Exception:
            return None
        return None

class AdminUserCreateUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer para a criação (CREATE) e atualização (UPDATE) de utilizadores.
    """
    class Meta:
        model = User
        fields = [
            'first_name', 'last_name', 'email', 'cpf', 
            'user_type', 'is_active', 'password'
        ]
        extra_kwargs = {
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