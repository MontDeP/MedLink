# administrador/serializers.py
from rest_framework import serializers
from django.db import transaction
from clinicas.models import Clinica, Cidade, TipoClinica, Estado
from users.models import User, Admin
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

class ClinicWithAdminCreateSerializer(serializers.Serializer):
    # Clinic fields
    clinic_name = serializers.CharField(max_length=255)
    clinic_cnpj = serializers.CharField(max_length=32, required=False, allow_blank=True)
    # Admin fields
    admin_first_name = serializers.CharField(max_length=150)
    admin_last_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    admin_cpf = serializers.CharField(max_length=14)
    admin_email = serializers.EmailField()
    admin_password = serializers.CharField(write_only=True)

    # NOVOS CAMPOS (opcionais) para obedecer ao modelo Clinica (NOT NULL)
    clinic_city_id = serializers.IntegerField(required=False, allow_null=True)
    clinic_type_id = serializers.IntegerField(required=False, allow_null=True)

    def validate_admin_cpf(self, value):
        v = value.strip()
        if User.objects.filter(cpf=v).exists():
            raise serializers.ValidationError("CPF já cadastrado.")
        return v

    def validate_admin_email(self, value):
        v = value.strip().lower()
        if User.objects.filter(email=v).exists():
            raise serializers.ValidationError("E-mail já cadastrado.")
        return v

    def validate(self, attrs):
        # Normaliza CNPJ (apenas dígitos)
        raw_cnpj = (attrs.get('clinic_cnpj') or '').strip()
        digits_cnpj = ''.join([c for c in raw_cnpj if c.isdigit()])
        attrs['clinic_cnpj'] = digits_cnpj

        if digits_cnpj:
            if Clinica.objects.filter(cnpj=digits_cnpj).exists():
                raise serializers.ValidationError({"clinic_cnpj": "CNPJ já cadastrado."})
        return attrs

    def _get_or_create_defaults(self):
        """
        Retorna (cidade, tipo_clinica) default quando não enviados:
        - Usa o primeiro registro existente
        - Se não existir, cria Estado 'DF', Cidade 'Brasília' e Tipo 'Clínica Geral'
        """
        cidade = Cidade.objects.first()
        tipo = TipoClinica.objects.first()

        if not cidade:
            uf, _ = Estado.objects.get_or_create(uf='DF', defaults={'nome': 'Distrito Federal'})
            cidade, _ = Cidade.objects.get_or_create(nome='Brasília', estado=uf)

        if not tipo:
            tipo, _ = TipoClinica.objects.get_or_create(descricao='Clínica Geral')

        return cidade, tipo

    def _resolve_city_and_type(self, clinic_city_id, clinic_type_id):
        cidade = None
        tipo = None

        if clinic_city_id:
            try:
                cidade = Cidade.objects.get(pk=int(clinic_city_id))
            except Exception:
                cidade = None
        if clinic_type_id:
            try:
                tipo = TipoClinica.objects.get(pk=int(clinic_type_id))
            except Exception:
                tipo = None

        if not cidade or not tipo:
            def_city, def_type = self._get_or_create_defaults()
            cidade = cidade or def_city
            tipo = tipo or def_type

        return cidade, tipo

    def create(self, validated_data):
        with transaction.atomic():
            # Resolve Cidade/Tipo (com fallback seguro)
            clinic_city_id = validated_data.pop('clinic_city_id', None)
            clinic_type_id = validated_data.pop('clinic_type_id', None)
            cidade, tipo = self._resolve_city_and_type(clinic_city_id, clinic_type_id)

            # 1) Criar clínica (cnpj já normalizado)
            clinica = Clinica.objects.create(
                nome_fantasia=validated_data.get('clinic_name').strip(),
                cnpj=validated_data.get('clinic_cnpj', ''),
                cidade=cidade,
                tipo_clinica=tipo,
            )

            # 2) Criar usuário admin da clínica
            user = User.objects.create_user(
                cpf=validated_data['admin_cpf'].strip(),
                email=validated_data['admin_email'].strip().lower(),
                password=validated_data['admin_password'],
                first_name=validated_data['admin_first_name'].strip(),
                last_name=validated_data.get('admin_last_name', '').strip(),
                user_type='ADMIN',
                is_active=True,
            )

            # 3) Vincular perfil Admin e marcar responsável
            Admin.objects.create(user=user, clinica=clinica)
            clinica.responsavel = user
            clinica.save(update_fields=['responsavel'])

            return clinica

    def to_representation(self, instance):
        return {
            'id': getattr(instance, 'id', None),
            'nome_fantasia': getattr(instance, 'nome_fantasia', None) or getattr(instance, 'nome', None),
            'cnpj': getattr(instance, 'cnpj', None),
        }

# --- NOVO: Listagem de Clínicas para o Super Admin ---
class ClinicaListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Clinica
        fields = ['id', 'nome_fantasia', 'cnpj']

class AssignClinicAdminSerializer(serializers.Serializer):
    """
    Atribui um Admin a uma clínica:
    - Pode vincular usuário existente por admin_user_id, cpf ou email
    - Ou criar um novo usuário Admin com os campos enviados
    """
    admin_user_id = serializers.IntegerField(required=False)
    cpf = serializers.CharField(required=False, allow_blank=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    first_name = serializers.CharField(required=False, allow_blank=True)
    last_name = serializers.CharField(required=False, allow_blank=True)
    password = serializers.CharField(required=False, write_only=True, allow_blank=True)

    def validate(self, attrs):
        # Garante algum identificador informado
        if not any([attrs.get('admin_user_id'), attrs.get('cpf'), attrs.get('email')]):
            raise serializers.ValidationError(
                "Informe ao menos um identificador: admin_user_id, cpf ou email."
            )
        return attrs

    def create(self, validated_data):
        """
        Fluxo:
        1) Se admin_user_id vier: usa esse usuário.
        2) Senão, tenta localizar por CPF ou e-mail.
        3) Se não existir, cria um novo Admin (requer cpf, email, first_name, password).
        4) Garante user_type='ADMIN', cria/atualiza perfil Admin e define clinic.responsavel.
        """
        clinic = self.context['clinic']

        user = None
        admin_user_id = validated_data.get('admin_user_id')
        cpf = (validated_data.get('cpf') or '').strip()
        email = (validated_data.get('email') or '').strip().lower()

        # 1) Buscar por ID
        if admin_user_id:
            user = User.objects.filter(id=admin_user_id).first()
            if not user:
                raise serializers.ValidationError({"admin_user_id": "Usuário não encontrado."})
        else:
            # 2) Buscar por CPF / E-mail
            if cpf:
                user = User.objects.filter(cpf=cpf).first()
            if not user and email:
                user = User.objects.filter(email=email).first()

        # 3) Criar novo usuário Admin se não existir
        if not user:
            first_name = (validated_data.get('first_name') or '').strip()
            last_name = (validated_data.get('last_name') or '').strip()
            password = (validated_data.get('password') or '').strip()
            if not (cpf and email and first_name and password):
                raise serializers.ValidationError(
                    {"detail": "Para criar um novo admin informe CPF, E-mail, Primeiro Nome e Senha."}
                )
            user = User.objects.create_user(
                cpf=cpf,
                email=email,
                password=password,
                first_name=first_name,
                last_name=last_name,
                user_type='ADMIN',
                is_active=True,
            )

        # 4) Garante tipo ADMIN e perfil Admin apontando para a clínica
        if user.user_type != 'ADMIN':
            user.user_type = 'ADMIN'
            user.save(update_fields=['user_type'])

        Admin.objects.update_or_create(user=user, defaults={'clinica': clinic})

        clinic.responsavel = user
        clinic.save(update_fields=['responsavel'])

        return user