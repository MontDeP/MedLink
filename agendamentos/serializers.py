# agendamentos/serializers.py

from rest_framework import serializers
from .models import Consulta, Pagamento, AnotacaoConsulta 
from users.models import User
from pacientes.models import Paciente
from clinicas.models import Clinica
from medicos.models import Medico

class PagamentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Pagamento
        fields = ['status', 'valor_pago', 'data_pagamento']

class ConsultaSerializer(serializers.ModelSerializer):
    pagamento = PagamentoSerializer(read_only=True)
    paciente_detalhes = serializers.SerializerMethodField()
    medico_detalhes = serializers.SerializerMethodField()
    clinica_detalhes = serializers.SerializerMethodField()
    anotacao_conteudo = serializers.SerializerMethodField()

    class Meta:
        model = Consulta
        fields = [
            'id', 'data_hora', 'status_atual', 'valor', 'paciente', 'medico', 'clinica',
            'paciente_detalhes', 'medico_detalhes', 'clinica_detalhes', 'pagamento',
            'anotacao_conteudo'
        ]
        read_only_fields = ['pagamento']

    # --- MÉTODO CORRIGIDO (ADICIONADO) ---
    def get_paciente_detalhes(self, obj):
        """
        Retorna um dicionário com detalhes do paciente associado à consulta.
        Esta era a função que faltava para corrigir o erro.
        """
        if obj.paciente:
            return {
                'id': obj.paciente.user.id, # Corrigido para pegar o id do user
                # ATENÇÃO: Verifique se os nomes dos campos abaixo ('nome_completo', 'cpf')
                # correspondem exatamente ao seu modelo 'Paciente'.
                'nome_completo': obj.paciente.nome_completo,
                'cpf': obj.paciente.user.cpf, # Corrigido para pegar o cpf do user
            }
        return None

    def get_anotacao_conteudo(self, obj):
        """ Busca o conteúdo da anotação associada a esta consulta. """
        try:
            # 'anotacao' é o related_name que definimos no modelo AnotacaoConsulta
            return obj.anotacao.conteudo
        except AnotacaoConsulta.DoesNotExist:
            # Se não houver anotação para a consulta, retorna nulo
            return None

    def get_medico_detalhes(self, obj):
        if obj.medico:
            try:
                perfil_medico = obj.medico.perfil_medico
                return {
                    'id': obj.medico.id,
                    'nome_completo': obj.medico.get_full_name(),
                    'email': obj.medico.email,
                    'crm': perfil_medico.crm,
                    'especialidade': perfil_medico.get_especialidade_display(),
                }
            except Medico.DoesNotExist:
                return {
                    'id': obj.medico.id,
                    'nome_completo': obj.medico.get_full_name(),
                    'email': obj.medico.email,
                    'crm': None,
                    'especialidade': None,
                }
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

class AnotacaoConsultaSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnotacaoConsulta
        fields = ['consulta', 'conteudo', 'data_atualizacao']
        read_only_fields = ['consulta', 'data_atualizacao']

class DashboardConsultaSerializer(serializers.ModelSerializer):
    """
    Serializer otimizado para o card de "Próxima Consulta" do dashboard do paciente.
    Retorna apenas os 4 campos necessários para o front-end.
    """

    # O front-end espera 'medico', 'especialidade', 'data', 'local'

    # Pega o nome completo do User (médico)
    medico = serializers.CharField(source='medico.get_full_name') 
    
    # Acessa User -> perfil_medico -> get_especialidade_display()
    #
    especialidade = serializers.CharField(source='medico.perfil_medico.get_especialidade_display')

    # Renomeia 'data_hora' para 'data'
    data = serializers.DateTimeField(source='data_hora') 

    # Pega o nome da clínica
    local = serializers.CharField(source='clinica.nome_fantasia') # Assumindo que o nome do local é 'nome_fantasia' no model Clinica

    class Meta:
        model = Consulta
        # Estes são os campos que o JSON final terá
        fields = ['medico', 'especialidade', 'data', 'local']