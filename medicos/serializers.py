from rest_framework import serializers
from .models import Medico
from users.models import User

# Serializer auxiliar para os dados do usuário
class UserForDoctorSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='get_full_name')

    class Meta:
        model = User
        fields = ['id', 'full_name', 'email']

# Em medicos/serializers.py
class MedicoSerializer(serializers.ModelSerializer):
    user = UserForDoctorSerializer(read_only=True)
    especialidade_label = serializers.CharField(source='get_especialidade_display', read_only=True)
    class Meta:
        model = Medico
        fields = ['crm', 'especialidade', 'especialidade_label', 'user']