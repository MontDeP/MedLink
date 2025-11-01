# administrador/views.py
from rest_framework import viewsets, filters, status, permissions, serializers
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from django.db import transaction
from django.db.models import Q
from django.db.models import Exists, OuterRef
from agendamentos.models import Consulta

# Modelos do projeto
from users.models import User, Admin
from pacientes.models import Paciente
from medicos.models import Medico
from secretarias.models import Secretaria
from .models import LogEntry
from clinicas.models import Clinica
from clinicas.serializers import ClinicaSerializer  # <-- ADICIONADO

# Serializers do app
from .serializers import (
    AdminUserSerializer,
    AdminUserCreateUpdateSerializer,
    LogEntrySerializer,
    ClinicWithAdminCreateSerializer,  # NEW
    ClinicaListSerializer,  # NEW
    AssignClinicAdminSerializer,  # NEW
)

from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.core.mail import send_mail
from django.conf import settings
from rest_framework import generics
from django.shortcuts import get_object_or_404

# --- NOVO: permissão para Superuser OU Admin de clínica ---
class IsSuperOrClinicAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        user = getattr(request, 'user', None)
        if not user or not user.is_authenticated:
            return False
        if getattr(user, 'is_superuser', False):
            return True
        # Admin de clínica precisa ter perfil_admin com clínica vinculada
        return str(getattr(user, 'user_type', '')).upper() == 'ADMIN' and hasattr(user, 'perfil_admin') and getattr(user.perfil_admin, 'clinica_id', None) is not None

class AdminUserViewSet(viewsets.ModelViewSet):
    """
    Endpoint da API para administradores gerirem todos os utilizadores do sistema.
    """
    queryset = User.objects.all().order_by('first_name')
    permission_classes = [IsSuperOrClinicAdmin]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['user_type', 'is_active']
    search_fields = ['first_name', 'last_name', 'email', 'cpf']

    def get_queryset(self):
        request = self.request
        user = request.user
        qs = User.objects.all().order_by('first_name', 'last_name')

        # Querystring opcional: ?clinica=ID
        clinica_param = request.query_params.get('clinica')
        clinica_id_qs = None
        try:
            if clinica_param:
                clinica_id_qs = int(clinica_param)
        except Exception:
            clinica_id_qs = None

        # Helper: marca usuários PACIENTE que têm ao menos uma consulta na clínica alvo
        def annotate_has_consulta(qs_in, clinica_id: int):
            return qs_in.annotate(
                _has_consulta_na_clinica=Exists(
                    Consulta.objects.filter(
                        paciente__user=OuterRef('pk'),
                        clinica_id=clinica_id,
                    )
                )
            )

        # SUPERUSER: vê todos; se clinica informada, aplica filtro
        if getattr(user, 'is_superuser', False):
            if clinica_id_qs:
                qs_ann = annotate_has_consulta(qs, clinica_id_qs)
                return qs_ann.filter(
                    Q(perfil_secretaria__clinica_id=clinica_id_qs) |
                    Q(perfil_medico__clinicas__id=clinica_id_qs) |
                    Q(paciente__clinica_id=clinica_id_qs) |
                    Q(perfil_admin__clinica_id=clinica_id_qs) |
                    (Q(user_type='PACIENTE') & Q(_has_consulta_na_clinica=True))
                ).distinct().order_by('first_name', 'last_name')
            return qs

        # ADMIN de clínica: restringe à própria clínica
        if getattr(user, 'user_type', None) == 'ADMIN' and hasattr(user, 'perfil_admin'):
            clinica_id_admin = getattr(user.perfil_admin, 'clinica_id', None)
            if not clinica_id_admin:
                return User.objects.none()
            qs_ann = annotate_has_consulta(qs, clinica_id_admin)
            return qs_ann.filter(
                Q(perfil_secretaria__clinica_id=clinica_id_admin) |
                Q(perfil_medico__clinicas__id=clinica_id_admin) |
                Q(paciente__clinica_id=clinica_id_admin) |
                Q(perfil_admin__clinica_id=clinica_id_admin) |
                (Q(user_type='PACIENTE') & Q(_has_consulta_na_clinica=True))
            ).distinct().order_by('first_name', 'last_name')

        return User.objects.none()

    def create(self, request, *args, **kwargs):
        """
        Criação de usuários com tratamento especial para MÉDICO:
        - Se e-mail/CPF já existir, não cria novo User; associa o médico existente à clínica do ADM (ou às clínicas enviadas).
        - Se não existir, segue o fluxo padrão (perform_create cria os perfis).
        """
        data = request.data
        user_type = (data.get('user_type') or '').upper()
        if user_type == 'MEDICO':
            email = data.get('email')
            cpf = data.get('cpf')

            if email or cpf:
                existing = User.objects.filter(
                    Q(email=email) | Q(cpf=cpf)
                ).first()

                if existing:
                    with transaction.atomic():
                        # Clínica do ADM (fallback)
                        admin_clinica_id = None
                        try:
                            admin_clinica_id = request.user.perfil_admin.clinica_id
                        except Exception:
                            admin_clinica_id = None

                        # Garante perfil de médico
                        medico = getattr(existing, 'perfil_medico', None)
                        crm = data.get('crm')
                        especialidade = data.get('especialidade')

                        if not medico:
                            if not crm or not especialidade:
                                return Response(
                                    {"detail": "CRM e Especialidade são obrigatórios para associar um médico existente."},
                                    status=status.HTTP_400_BAD_REQUEST,
                                )
                            if existing.user_type != 'MEDICO':
                                existing.user_type = 'MEDICO'
                                existing.save()
                            medico = Medico.objects.create(
                                user=existing,
                                crm=crm,
                                especialidade=especialidade,
                            )
                        else:
                            # Atualiza CRM/especialidade se enviados
                            changed = False
                            if crm and medico.crm != crm:
                                medico.crm = crm
                                changed = True
                            if especialidade and medico.especialidade != especialidade:
                                medico.especialidade = especialidade
                                changed = True
                            if changed:
                                medico.save()

                        # Determina as clínicas a associar: clinicas -> clinica_id -> ADM
                        clinicas_ids = []
                        raw_clinicas = data.get('clinicas')
                        if isinstance(raw_clinicas, list) and raw_clinicas:
                            try:
                                clinicas_ids = [int(x) for x in raw_clinicas if str(x).isdigit()]
                            except Exception:
                                clinicas_ids = []
                        if not clinicas_ids:
                            raw_single = data.get('clinica_id') or admin_clinica_id
                            if raw_single:
                                try:
                                    clinicas_ids = [int(raw_single)]
                                except Exception:
                                    clinicas_ids = []

                        if clinicas_ids:
                            medico.clinicas.add(*clinicas_ids)

                        LogEntry.objects.create(
                            actor=request.user,
                            action_type=LogEntry.ActionType.UPDATE,
                            details=f"Associou médico '{existing.get_full_name()}' às clínicas {clinicas_ids or '[]'}.",
                        )

                        # Serializa com o serializer de leitura
                        read_data = AdminUserSerializer(existing).data
                        return Response(read_data, status=status.HTTP_201_CREATED)

        # Fluxo padrão (criação de novo usuário)
        return super().create(request, *args, **kwargs)

    def get_serializer_class(self):
        # Usa um serializer diferente para ler vs. escrever
        if self.action in ['create', 'update', 'partial_update']:
            return AdminUserCreateUpdateSerializer
        return AdminUserSerializer

    def perform_create(self, serializer):
        """
        Cria o usuário e vincula o perfil à clínica correta.
        - Médico: usa lista 'clinicas' (M2M) se fornecida; senão usa 'clinica_id'; senão a clínica do admin.
        - Secretária/Paciente: usa 'clinica_id' se fornecida; senão a clínica do admin.
        """
        user = serializer.save()

        try:
            with transaction.atomic():
                # Clínica do admin (fallback seguro)
                admin_clinica_id = None
                try:
                    admin_clinica_id = self.request.user.perfil_admin.clinica_id
                except Exception:
                    admin_clinica_id = None

                if user.user_type == 'PACIENTE':
                    telefone = self.request.data.get('telefone', '')
                    clinica_id = self.request.data.get('clinica_id') or admin_clinica_id
                    # Vincula paciente à mesma clínica do admin se não vier no payload
                    Paciente.objects.create(user=user, telefone=telefone, clinica_id=clinica_id)

                elif user.user_type == 'MEDICO':
                    crm = self.request.data.get('crm')
                    especialidade = self.request.data.get('especialidade')

                    if not crm or not especialidade:
                        raise serializers.ValidationError({"detail": "CRM e Especialidade são obrigatórios para o perfil de Médico."})

                    # Cria o médico
                    medico = Medico.objects.create(
                        user=user,
                        crm=crm,
                        especialidade=especialidade,
                    )

                    # Determina as clínicas a vincular (prioridade: 'clinicas' -> 'clinica_id' -> do admin)
                    clinicas_ids = []
                    raw_clinicas = self.request.data.get('clinicas')
                    if isinstance(raw_clinicas, list) and raw_clinicas:
                        # lista enviada pelo frontend
                        try:
                            clinicas_ids = [int(x) for x in raw_clinicas if str(x).isdigit()]
                        except Exception:
                            clinicas_ids = []
                    if not clinicas_ids:
                        raw_single = self.request.data.get('clinica_id') or admin_clinica_id
                        if raw_single:
                            try:
                                clinicas_ids = [int(raw_single)]
                            except Exception:
                                clinicas_ids = []

                    if clinicas_ids:
                        medico.clinicas.add(*clinicas_ids)

                elif user.user_type == 'SECRETARIA':
                    clinica_id = self.request.data.get('clinica_id') or admin_clinica_id
                    if not clinica_id:
                        raise serializers.ValidationError({"detail": "A Clínica é obrigatória para o perfil de Secretária."})
                    Secretaria.objects.create(user=user, clinica_id=clinica_id)

                elif user.user_type == 'ADMIN':
                    # Novo: cria perfil Admin vinculado a uma clínica (obrigatória)
                    clinica_id = (
                        self.request.data.get('clinica')
                        or self.request.data.get('clinica_id')
                        or admin_clinica_id
                    )
                    if not clinica_id:
                        raise serializers.ValidationError({"detail": "A Clínica é obrigatória para o perfil de Admin."})
                    Admin.objects.create(user=user, clinica_id=clinica_id)

                if user.user_type in [User.UserType.MEDICO, User.UserType.SECRETARIA]:
                    self.send_creation_email(user)

                LogEntry.objects.create(
                    actor=self.request.user,
                    action_type=LogEntry.ActionType.CREATE,
                    details=f"Criou o utilizador '{user.get_full_name()}' (CPF: {user.cpf}, Tipo: {user.get_user_type_display()})."
                )
        except Exception as e:
            user.delete()
            raise serializers.ValidationError({"detail": f"Falha ao criar perfil associado: {str(e)}"})
    def send_creation_email(self, user):
        """
        Gera o token e envia o e-mail para o novo usuário criar sua senha.
        """
        token = default_token_generator.make_token(user)
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        
        create_url = f'http://localhost:3000/criar-senha?uid={uid}&token={token}' 

        try:
            send_mail(
                'Bem-vindo(a) à MedLink - Crie sua Senha',
                f'Olá {user.first_name},\n\nSua conta na MedLink foi criada com sucesso. Por favor, clique no link abaixo para definir sua senha de acesso:\n\n{create_url}\n\nSe você não esperava por isso, ignore este e-mail.',
                settings.DEFAULT_FROM_EMAIL,
                [user.email],
                fail_silently=False,
            )
        except Exception as e:
        
            print(f"Erro ao enviar email de criação de senha: {e}")
            pass
    def perform_update(self, serializer):
        """ Sobrescreve para adicionar log na atualização. """
        user = serializer.save()
        LogEntry.objects.create(
            actor=self.request.user,
            action_type=LogEntry.ActionType.UPDATE,
            details=f"Atualizou o utilizador '{user.get_full_name()}' (CPF: {user.cpf})."
        )

    def perform_destroy(self, instance):
        """ Sobrescreve para adicionar log na remoção. """
        details = f"Removeu o utilizador '{instance.get_full_name()}' (CPF: {instance.cpf})."
        instance.delete()
        LogEntry.objects.create(
            actor=self.request.user,
            action_type=LogEntry.ActionType.DELETE,
            details=details
        )


class AdminDashboardStatsAPIView(APIView):
    """
    Endpoint para fornecer as estatísticas agregadas para o painel de administração.
    """
    # CORREÇÃO: Usando a permissão padrão do Django REST Framework.
    permission_classes = [permissions.IsAdminUser]

    def get(self, request, *args, **kwargs):
        total_users = User.objects.count()
        active_users = User.objects.filter(is_active=True).count()
        
        total_doctors = User.objects.filter(user_type='MEDICO').count()
        total_secretaries = User.objects.filter(user_type='SECRETARIA').count()
        total_patients = User.objects.filter(user_type='PACIENTE').count()

        stats = {
            'total': total_users,
            'active': active_users,
            'doctors': total_doctors,
            'secretaries': total_secretaries,
            'patients': total_patients,
        }
        
        return Response(stats, status=status.HTTP_200_OK)


class LogEntryViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Endpoint para visualizar os registos de log (auditoria).
    Apenas permite a leitura (listagem e detalhe).
    """
    queryset = LogEntry.objects.all()
    serializer_class = LogEntrySerializer
    # CORREÇÃO: Usando a permissão padrão do Django REST Framework.
    permission_classes = [permissions.IsAdminUser]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['action_type', 'actor']
    search_fields = ['details', 'actor__cpf', 'actor__first_name']

# --- NEW: Super Admin permission ---
class IsSuperAdmin(permissions.BasePermission):
    """
    Allows access only to Super Admins. Supports future user_type='ADMIN_GERAL'
    and current Django superuser.
    """
    def has_permission(self, request, view):
        user = getattr(request, 'user', None)
        if not user or not user.is_authenticated:
            return False
        if getattr(user, 'is_superuser', False):
            return True
        return str(getattr(user, 'user_type', '')).upper() == 'ADMIN_GERAL'

# --- NEW: Create Clinic + first Clinic Admin ---
class ClinicWithAdminCreateView(generics.CreateAPIView):
    permission_classes = [IsSuperAdmin]
    serializer_class = ClinicWithAdminCreateSerializer

# --- NOVO: Listagem de Clínicas (apenas Super Admin) ---
class ClinicaListView(generics.ListCreateAPIView):  # <-- de ListAPIView para ListCreateAPIView
    permission_classes = [IsSuperAdmin]
    serializer_class = ClinicaListSerializer

    def get_queryset(self):
        qs = Clinica.objects.all().order_by('nome_fantasia', 'id')
        term = self.request.query_params.get('search')
        if term:
            return qs.filter(nome_fantasia__icontains=term)
        return qs

    def get_serializer_class(self):
        # GET: lista “leve”; POST: serializer completo do app clinicas
        if self.request.method == 'POST':
            return ClinicaSerializer
        return ClinicaListSerializer

# --- NEW: Detalhar/Editar clínica (apenas Super Admin) ---
class ClinicaAdminDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsSuperAdmin]
    queryset = Clinica.objects.all()
    serializer_class = ClinicaSerializer

# --- NEW: Atribuir Admin à clínica (apenas Super Admin) ---
class AssignClinicAdminAPIView(APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk, *args, **kwargs):
        clinic = get_object_or_404(Clinica, pk=pk)
        serializer = AssignClinicAdminSerializer(data=request.data, context={'clinic': clinic})
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            {
                "message": "Administrador atribuído com sucesso.",
                "clinic_id": clinic.id,
                "admin_user_id": user.id,
                "admin_name": user.get_full_name(),
                "admin_email": user.email,
            },
            status=status.HTTP_200_OK,
        )