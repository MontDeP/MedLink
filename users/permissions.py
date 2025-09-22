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
