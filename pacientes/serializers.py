# pacientes/serializers.py 

from rest_framework import serializers
from .models import Paciente
from users.models import User
from django.db import transaction
import re 
from notificacoes.models import Notificacao

class PacienteCreateSerializer(serializers.ModelSerializer):
    cpf = serializers.CharField(write_only=True, required=True)
    email = serializers.EmailField(write_only=True, required=True)
    password = serializers.CharField(write_only=True, required=True)
    first_name = serializers.CharField(write_only=True, required=True)
    last_name = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Paciente
        fields = ['cpf', 'email', 'password', 'first_name', 'last_name', 'telefone']

    @transaction.atomic
    def create(self, validated_data):
        validated_data['telefone'] = re.sub(r'\D', '', validated_data.get('telefone', ''))

        user_data = {
            'cpf': validated_data.pop('cpf'),
            'email': validated_data.pop('email'),
            'password': validated_data.pop('password'),
            'first_name': validated_data.pop('first_name'),
            'last_name': validated_data.pop('last_name', ''),
            'user_type': 'PACIENTE'
        }

        user_data['cpf'] = re.sub(r'\D', '', user_data.get('cpf', ''))

        user = User.objects.create_user(**user_data)
        paciente = Paciente.objects.create(user=user, **validated_data)
        return paciente

    def to_representation(self, instance):
        representation = {}
        user = instance.user
        representation['id'] = user.id
        representation['email'] = user.email
        representation['cpf'] = user.cpf
        representation['nome_completo'] = user.get_full_name()
        representation['telefone'] = instance.telefone
        return representation

# Serializer para os campos do usuário que queremos expor/editar no perfil
class UserProfileSerializer(serializers.ModelSerializer):
    nome_completo = serializers.CharField(source='get_full_name', read_only=True)

    class Meta:
        model = User
        # Campos que o paciente pode ver e os que pode atualizar
        fields = ['cpf', 'email', 'first_name', 'last_name', 'nome_completo']
        # Paciente não deve mudar CPF ou email por aqui
        read_only_fields = ['cpf', 'email', 'nome_completo'] 

# Serializer principal do Perfil do Paciente (para a nova API)
class PacienteProfileSerializer(serializers.ModelSerializer):
    # Aninha o serializer do User
    user = UserProfileSerializer()

    class Meta:
        model = Paciente
        # Lista todos os campos do Paciente que queremos na API
        # (usando o nome do campo do models.py, 'informacoes_adicionais')
        fields = [
            'user', 'telefone', 'altura_cm', 'peso_kg', 'data_nascimento',
            'tipo_sanguineo', 'cep', 'bairro', 'quadra', 'av_rua', 'numero',
            'informacoes_adicionais'
        ]

    @transaction.atomic
    def update(self, instance, validated_data):
        # 1. Pega os dados do 'user' aninhado que vieram no JSON
        user_data = validated_data.pop('user', {})
        
        # 2. Atualiza os campos do User (first_name, last_name)
        user = instance.user
        # O 'user' é aninhado, então 'user_data' é um dict
        user.first_name = user_data.get('first_name', user.first_name)
        user.last_name = user_data.get('last_name', user.last_name)
        user.save()

        cep_value = validated_data.get('cep')
        if cep_value is not None:
             # Remove tudo que não for dígito do CEP antes de salvar
             validated_data['cep'] = re.sub(r'\D', '', cep_value)

        # 3. Atualiza os campos do Paciente (a 'instance' principal)
        # Esta é a forma padrão de 'update' do serializer
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        Notificacao.objects.create(
            usuario=instance.user, # instance.user é o usuário paciente
            titulo="Perfil atualizado",
            mensagem="Os dados do seu perfil foram alterados com sucesso.",
            tipo=Notificacao.TipoNotificacao.SEGURANCA
        )
        return instance