from rest_framework import serializers
from .models import Clinica, Cidade, Estado, TipoClinica

class EstadoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Estado
        fields = '__all__'

class CidadeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Cidade
        fields = '__all__'

class TipoClinicaSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoClinica
        fields = '__all__'

class ClinicaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Clinica
        fields = '__all__'

class ClinicaListSerializer(serializers.ModelSerializer):
    """
    Serializer enxuto para listar clínicas no app do paciente.
    """
    class Meta:
        model = Clinica
        fields = ['id', 'nome_fantasia']