# users/views.py
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import MyTokenObtainPairSerializer
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes, force_str
from django.core.mail import send_mail
from django.conf import settings
from django.db.models import Q
from django.shortcuts import get_object_or_404
import logging

logger = logging.getLogger(__name__)

User = get_user_model()

class MyTokenObtainPairView(TokenObtainPairView):
    serializer_class = MyTokenObtainPairSerializer

class PasswordResetRequestView(APIView):
    """
    View para solicitar a redefinição de senha.
    Aceita um POST com um 'email'.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({'error': 'Email é obrigatório'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Busca o usuário pelo email
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            return Response({'error': 'Usuário com este email não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        # Gerar token e UID
        token = default_token_generator.make_token(user)
        uid = urlsafe_base64_encode(force_bytes(user.pk))

        # 
        # ATENÇÃO AQUI: Verifique se a porta 3000 está correta
        # Nos prints anteriores, seu Flutter estava na porta 8080.
        # Coloque a porta correta do seu front-end aqui.
        #
        reset_url = f'http://localhost:3000/reset-password?uid={uid}&token={token}' 
        # Se o seu Flutter roda na 8080, mude para:
        # reset_url = f'http://localhost:8080/reset-password?uid={uid}&token={token}'

        # Enviar o e-mail
        try:
            send_mail(
                'Recuperação de Senha - MedLink',
                f'Olá,\n\nVocê solicitou a recuperação de senha. Clique no link abaixo para criar uma nova senha:\n\n{reset_url}\n\nSe você não solicitou isso, ignore este e-mail.',
                settings.DEFAULT_FROM_EMAIL,
                [user.email],
                fail_silently=False,
            )
            return Response({'message': 'Email de recuperação enviado.'}, status=status.HTTP_200_OK)
        except Exception as e:
            print(f"Erro ao enviar email: {e}")
            return Response({'error': 'Erro ao enviar o e-mail.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class PasswordResetConfirmView(APIView):
    """
    View para confirmar a redefinição de senha.
    Aceita POST com uid, token e password.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        uidb64 = request.data.get('uid')
        token = request.data.get('token')
        password = request.data.get('password')

        if not uidb64 or not token or not password:
            return Response({'error': 'UID, token e nova senha são obrigatórios.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Decodifica o UID
            uid = force_str(urlsafe_base64_decode(uidb64))
            user = User.objects.get(pk=uid)
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            user = None

        # Verifica se o usuário existe e se o token é válido
        if user is not None and default_token_generator.check_token(user, token):
            # Define a senha E ativa o usuário
            user.set_password(password)
            user.is_active = True  # <-- ADICIONE ESTA LINHA
            user.save()
            return Response({'message': 'Senha definida com sucesso.'}, status=status.HTTP_200_OK)
            # Se tudo estiver OK, define a nova senha
            user.set_password(password)
            user.save()
            return Response({'message': 'Senha redefinida com sucesso.'}, status=status.HTTP_200_OK)
        else:
            # Se o token for inválido ou o UID estiver errado
            return Response({'error': 'O link de redefinição é inválido ou expirou.'}, status=status.HTTP_400_BAD_REQUEST)
        
class PasswordCreateConfirmView(APIView):
    """
    View para o usuário DEFINIR a senha pela primeira vez.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        uidb64 = request.data.get('uid')
        token = request.data.get('token')
        password = request.data.get('password')

        if not uidb64 or not token or not password:
            return Response({'error': 'UID, token e nova senha são obrigatórios.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            uid = force_str(urlsafe_base64_decode(uidb64))
            user = User.objects.get(pk=uid)
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            user = None

        # Verifica se o usuário existe e se o token é válido
        if user is not None and default_token_generator.check_token(user, token):
            # A única diferença: NÃO verificamos a senha antiga.
            user.set_password(password)
            user.save()
            return Response({'message': 'Senha definida com sucesso.'}, status=status.HTTP_200_OK)
        else:
            return Response({'error': 'O link para criar a senha é inválido ou expirou.'}, status=status.HTTP_400_BAD_REQUEST)

class UserManagementView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def _user_clinica_id(self, u):
        """Retorna clinica_id (FK) quando aplicável ou None."""
        try:
            if u.user_type == 'SECRETARIA' and hasattr(u, 'perfil_secretaria'):
                return getattr(u.perfil_secretaria, 'clinica_id', None)
            if u.user_type == 'PACIENTE' and hasattr(u, 'perfil_paciente'):
                return getattr(u.perfil_paciente, 'clinica_id', None)
            if u.user_type == 'ADMIN' and hasattr(u, 'perfil_admin'):
                return getattr(u.perfil_admin, 'clinica_id', None)
        except Exception:
            return None
        return None

    def _user_clinica_ids_medico(self, u):
        """Retorna lista de clinica_ids para médicos (M2M)."""
        try:
            if u.user_type == 'MEDICO' and hasattr(u, 'perfil_medico'):
                return list(u.perfil_medico.clinicas.values_list('id', flat=True))
        except Exception:
            return []
        return []

    def get(self, request, pk=None):
        user = request.user
        clinica_param = request.query_params.get('clinica')
        clinica_id_alvo = None
        if clinica_param:
            try:
                clinica_id_alvo = int(clinica_param)
            except Exception:
                clinica_id_alvo = None

        # LOG INICIAL
        logger.info(f"[UserManagementView] user={user.id} ({user.get_full_name()}) type={getattr(user,'user_type',None)} is_staff={user.is_staff} is_superuser={user.is_superuser} clinica_param={clinica_param}")

        if user.is_superuser and not clinica_id_alvo:
            queryset = User.objects.all().order_by('first_name', 'last_name')
        else:
            if user.user_type == 'ADMIN' and hasattr(user, 'perfil_admin'):
                if not clinica_id_alvo:
                    clinica_id_alvo = getattr(user.perfil_admin, 'clinica_id', None)
            if not clinica_id_alvo:
                queryset = User.objects.none()
            else:
                queryset = User.objects.filter(
                    Q(perfil_secretaria__clinica_id=clinica_id_alvo) |
                    Q(perfil_medico__clinicas__id=clinica_id_alvo) |
                    Q(perfil_paciente__clinica_id=clinica_id_alvo) |
                    Q(perfil_admin__clinica_id=clinica_id_alvo)
                ).distinct().order_by('first_name', 'last_name')

        # LOG DO RESULTADO
        try:
            logger.info(f"[UserManagementView] clinica_id_alvo={clinica_id_alvo} count={queryset.count()}")
        except Exception:
            logger.info(f"[UserManagementView] clinica_id_alvo={clinica_id_alvo} count=?")

        if pk:
            user_obj = get_object_or_404(queryset, pk=pk)
            data = {
                'id': user_obj.id,
                'first_name': user_obj.first_name,
                'last_name': user_obj.last_name,
                'full_name': user_obj.get_full_name(),
                'cpf': user_obj.cpf,
                'email': user_obj.email,
                'user_type': user_obj.user_type,
                'is_active': user_obj.is_active,
                'date_joined': user_obj.date_joined,
                'last_login': user_obj.last_login,
                # Campos de clínica para o front filtrar/mostrar
                'clinica_id': self._user_clinica_id(user_obj),
                'clinica_ids': self._user_clinica_ids_medico(user_obj),
            }
            if user_obj.user_type == 'MEDICO' and hasattr(user_obj, 'perfil_medico'):
                data['specialty'] = user_obj.perfil_medico.get_especialidade_display()
                data['crm'] = user_obj.perfil_medico.crm
            return Response(data)

        users_data = []
        for u in queryset:
            user_data = {
                'id': u.id,
                'first_name': u.first_name,
                'last_name': u.last_name,
                'full_name': u.get_full_name(),
                'cpf': u.cpf,
                'email': u.email,
                'user_type': u.user_type,
                'is_active': u.is_active,
                'date_joined': u.date_joined,
                'last_login': u.last_login,
                # Campos de clínica para o front filtrar/mostrar
                'clinica_id': self._user_clinica_id(u),
                'clinica_ids': self._user_clinica_ids_medico(u),
            }
            if u.user_type == 'MEDICO' and hasattr(u, 'perfil_medico'):
                user_data['specialty'] = u.perfil_medico.get_especialidade_display()
                user_data['crm'] = u.perfil_medico.crm
            users_data.append(user_data)

        return Response(users_data)

    # ...existing code (post, put, patch, delete)...