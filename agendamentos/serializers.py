from rest_framework import serializers
from .models import Consulta, Pagamento
from users.models import User
from pacientes.models import Paciente
from clinicas.models import Clinica

class PagamentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Pagamento
        fields = ['status', 'valor_pago', 'data_pagamento']

class ConsultaSerializer(serializers.ModelSerializer):
    # Serializador aninhado para o Pagamento.
    # O 'many=False' é o padrão, mas o incluímos por clareza em relações OneToOne.
    pagamento = PagamentoSerializer(read_only=True)
    
    # Adicionamos campos para exibir informações detalhadas dos objetos relacionados.
    paciente_detalhes = serializers.SerializerMethodField()
    medico_detalhes = serializers.SerializerMethodField()
    clinica_detalhes = serializers.SerializerMethodField()

    class Meta:
        model = Consulta
        fields = [
            'id', 'data_hora', 'status_atual', 'valor', 'paciente', 'medico', 'clinica',
            'paciente_detalhes', 'medico_detalhes', 'clinica_detalhes', 'pagamento'
        ]
        read_only_fields = ['pagamento']
    
    # Métodos para obter e serializar os detalhes dos objetos relacionados.
    def get_paciente_detalhes(self, obj):
        return {
            'id': obj.paciente.id,
            'nome_completo': obj.paciente.nome_completo,
            'cpf': obj.paciente.cpf,
        }

    def get_medico_detalhes(self, obj):
        try:
            medico_user = User.objects.get(id=obj.medico.id, user_type='MEDICO')
            # Aqui você pode adicionar mais detalhes do perfil do médico se o modelo Medico for implementado
            return {
                'id': medico_user.id,
                'nome_completo': medico_user.get_full_name(),
                'email': medico_user.email,
            }
        except User.DoesNotExist:
            return None

    def get_clinica_detalhes(self, obj):
        try:
            clinica = Clinica.objects.get(id=obj.clinica.id)
            return {
                'id': clinica.id,
                'nome_fantasia': clinica.nome_fantasia,
                'cnpj': clinica.cnpj,
            }
        except Clinica.DoesNotExist:
            return None
