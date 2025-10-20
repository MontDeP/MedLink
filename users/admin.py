# users/admin.py (VERSÃO SIMPLIFICADA)

from django.contrib import admin
from .models import User

# Apenas para garantir que o admin padrão do User não seja mais usado.
# Vamos registar os nossos admins personalizados noutros locais.
# Se o 'User' ainda estiver registado, descomente a linha abaixo:
# admin.site.unregister(User)

# Opcional: Um admin simples para utilizadores do tipo 'ADMIN' que não têm perfil
@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('cpf', 'email', 'get_full_name', 'user_type')
    list_filter = ('user_type', 'is_staff', 'is_active')
    search_fields = ('cpf', 'email', 'first_name', 'last_name')

    def get_queryset(self, request):
        # Mostra apenas admins e superusers nesta vista
        return super().get_queryset(request).filter(user_type='ADMIN')