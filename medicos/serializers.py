from rest_framework import serializers
from users.models import User
from clinicas.models import Clinica
from .models import Medico

# Serializer auxiliar para os dados do usuário
class UserForDoctorSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='get_full_name')

    class Meta:
        model = User
        fields = ['id', 'full_name', 'email']

# Em medicos/serializers.py
class MedicoSerializer(serializers.ModelSerializer):
    # ID do médico = id do usuário vinculado
    id = serializers.IntegerField(source='user.id', read_only=True)
    full_name = serializers.SerializerMethodField()
    fullName = serializers.SerializerMethodField()  # alias para o app Flutter

    class Meta:
        model = Medico
        fields = [
            'id',
            'full_name',
            'fullName',
            'especialidade',
            'crm',
        ]
        read_only_fields = ['id', 'full_name', 'fullName']

    def get_full_name(self, obj):
        return obj.user.get_full_name() if getattr(obj, 'user', None) else ''

    def get_fullName(self, obj):
        return self.get_full_name(obj)

    # Opcional: normaliza clinicas no create/update, caso o payload traga aliases
    def _extract_clinica_ids(self, data: dict):
        ids = []
        for key in ['clinicas', 'clinica', 'clinica_id', 'clinicaId', 'clinic_id']:
            if key in data:
                val = data.pop(key)
                seq = val if isinstance(val, (list, tuple, set)) else [val]
                for v in seq:
                    try:
                        ids.append(int(getattr(v, 'id', v)))
                    except Exception:
                        continue
        return ids

    def create(self, validated_data):
        clinica_ids = self._extract_clinica_ids(validated_data)
        instance = Medico.objects.create(**validated_data)
        if clinica_ids:
            instance.clinicas.set(Clinica.objects.filter(id__in=clinica_ids))
        return instance

    def update(self, instance, validated_data):
        clinica_ids = self._extract_clinica_ids(validated_data)
        instance = super().update(instance, validated_data)
        if clinica_ids:
            instance.clinicas.set(Clinica.objects.filter(id__in=clinica_ids))
        return instance