from rest_framework.permissions import BasePermission

class IsMedicoOrSecretaria(BasePermission):
    """
    Permissão customizada para permitir acesso apenas para usuários
    do tipo MÉDICO, SECRETÁRIA ou superusuários.
    """

    def has_permission(self, request, view):
        # Se for superuser, permite sempre
        if request.user and request.user.is_superuser:
            return True
        
        # Se não estiver logado, bloqueia
        if not request.user or not request.user.is_authenticated:
            return False
        
        # Permite apenas Médicos ou Secretárias
        return request.user.user_type in ['MEDICO', 'SECRETARIA']
class IsMedicoUser(BasePermission):
    """
    Permissão personalizada para permitir acesso apenas a utilizadores
    com o tipo 'MEDICO'.
    """
    def has_permission(self, request, view):
        # Verifica se o utilizador está autenticado e se o seu tipo é 'MEDICO'
        # A verificação 'request.user.is_authenticated' já está incluída na framework
        # quando usamos IsAuthenticated, mas é uma boa prática ser explícito.
        return request.user and request.user.is_authenticated and request.user.user_type == 'MEDICO'
    
class HasRole(BasePermission):
    """
    Permissão customizada que verifica o campo 'user_type' do usuário.
    """
    def has_permission(self, request, view):
        # Pega a lista de papéis necessários definida na view (ex: ['SECRETARIA'])
        required_roles = getattr(view, 'required_roles', [])

        # Nega o acesso se a view não definir nenhum papel
        if not required_roles:
            return False

        # Pega o usuário da requisição
        user = request.user

        # Verifica se o usuário está autenticado e se o seu 'user_type'
        # está na lista de papéis permitidos para esta view.
        return user and user.is_authenticated and user.user_type in required_roles
    
class IsAdminOrReadOnly(BasePermission):
    """
    Permissão personalizada que permite acesso total a administradores
    e apenas leitura para outros usuários autenticados.
    """
    def has_permission(self, request, view):
        # Permite acesso total se o usuário for administrador
        if request.user and request.user.is_staff:
            return True
        
        # Permite apenas métodos de leitura (GET, HEAD, OPTIONS) para outros usuários autenticados
        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return request.user and request.user.is_authenticated
        
        # Nega o acesso para outros métodos (POST, PUT, DELETE) para usuários não administradores
        return False