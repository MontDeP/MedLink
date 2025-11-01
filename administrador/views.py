# administrador/views.py
from rest_framework import viewsets, filters, status, permissions, serializers
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from django.db import transaction
from django.db.models import Q

# Modelos do projeto
from users.models import User
from pacientes.models import Paciente
from medicos.models import Medico
from secretarias.models import Secretaria
from .models import LogEntry

# Serializers do app
from .serializers import (
    AdminUserSerializer,
    AdminUserCreateUpdateSerializer,
    LogEntrySerializer
)

from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.core.mail import send_mail
from django.conf import settings

class AdminUserViewSet(viewsets.ModelViewSet):
    """
    Endpoint da API para administradores gerirem todos os utilizadores do sistema.
    """
    queryset = User.objects.all().order_by('first_name')
    permission_classes = [permissions.IsAdminUser]
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

        # SUPERUSER: vê todos; se clinica informada, aplica filtro
        if getattr(user, 'is_superuser', False):
            if clinica_id_qs:
                return qs.filter(
                    Q(perfil_secretaria__clinica_id=clinica_id_qs) |
                    Q(perfil_medico__clinicas__id=clinica_id_qs) |
                    Q(paciente__clinica_id=clinica_id_qs) |  # <-- corrigido
                    Q(perfil_admin__clinica_id=clinica_id_qs)
                ).distinct().order_by('first_name', 'last_name')
            return qs

        # ADMIN de clínica (funcionário/staff do DRF): restringe à própria clínica
        if getattr(user, 'user_type', None) == 'ADMIN' and hasattr(user, 'perfil_admin'):
            clinica_id_admin = getattr(user.perfil_admin, 'clinica_id', None)
            if not clinica_id_admin:
                return User.objects.none()
            # Ignora clinica diferente passada na URL; sempre restringe à do admin
            return qs.filter(
                Q(perfil_secretaria__clinica_id=clinica_id_admin) |
                Q(perfil_medico__clinicas__id=clinica_id_admin) |
                Q(paciente__clinica_id=clinica_id_admin) |  # <-- corrigido
                Q(perfil_admin__clinica_id=clinica_id_admin)
            ).distinct().order_by('first_name', 'last_name')

        # Qualquer outro perfil não deve acessar a listagem completa
        return User.objects.none()

    def get_serializer_class(self):
        # Usa um serializer diferente para ler vs. escrever
        if self.action in ['create', 'update', 'partial_update']:
            return AdminUserCreateUpdateSerializer
        return AdminUserSerializer

    def perform_create(self, serializer):
        """
        Sobrescreve o método padrão para criar perfis associados
        após a criação do usuário, garantindo a integridade dos dados.
        """
        user = serializer.save()

        try:
            with transaction.atomic():
                if user.user_type == 'PACIENTE':
                    telefone = self.request.data.get('telefone', '')
                    Paciente.objects.create(user=user, telefone=telefone)

                elif user.user_type == 'MEDICO':
                    crm = self.request.data.get('crm')
                    especialidade = self.request.data.get('especialidade')
                    clinica_id = self.request.data.get('clinica_id')

                    if not crm or not especialidade:
                        raise serializers.ValidationError({"detail": "CRM e Especialidade são obrigatórios para o perfil de Médico."})

                    # Cria o médico e vincula a(s) clínica(s) via M2M
                    medico = Medico.objects.create(
                        user=user,
                        crm=crm,
                        especialidade=especialidade,
                    )
                    if clinica_id:
                        try:
                            medico.clinicas.add(int(clinica_id))  # <-- M2M
                        except Exception:
                            pass

                elif user.user_type == 'SECRETARIA':
                    clinica_id = self.request.data.get('clinica_id')
                    if not clinica_id:
                        raise serializers.ValidationError({"detail": "A Clínica é obrigatória para o perfil de Secretária."})
                    Secretaria.objects.create(user=user, clinica_id=clinica_id)

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