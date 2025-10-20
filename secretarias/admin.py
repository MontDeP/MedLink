# secretarias/admin.py (NOVA VERSÃO)

from django.contrib import admin
from .models import Secretaria, SecretariaUser
from users.models import User

# Inline para o perfil de Secretária
class SecretariaProfileInline(admin.StackedInline):
    model = Secretaria
    can_delete = False
    verbose_name_plural = 'Perfil da Secretária'

@admin.register(SecretariaUser)
class SecretariaUserAdmin(admin.ModelAdmin):
    # Mostra apenas utilizadores do tipo SECRETARIA nesta secção
    def get_queryset(self, request):
        return User.objects.filter(user_type='SECRETARIA')

    # Define o 'user_type' por defeito ao criar
    def save_model(self, request, obj, form, change):
        obj.user_type = 'SECRETARIA'
        super().save_model(request, obj, form, change)

    inlines = [SecretariaProfileInline]
    list_display = ('email', 'get_full_name', 'is_active')
    fields = ('first_name', 'last_name', 'cpf', 'email', 'password')