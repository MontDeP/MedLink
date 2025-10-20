# medicos/admin.py (NOVA VERSÃO)

from django.contrib import admin
from .models import Medico, MedicoUser
from users.models import User

class MedicoProfileInline(admin.StackedInline):
    model = Medico
    can_delete = False
    verbose_name_plural = 'Perfil do Médico'

@admin.register(MedicoUser)
class MedicoUserAdmin(admin.ModelAdmin):
    def get_queryset(self, request):
        return User.objects.filter(user_type='MEDICO')

    def save_model(self, request, obj, form, change):
        obj.user_type = 'MEDICO'
        super().save_model(request, obj, form, change)

    inlines = [MedicoProfileInline]
    list_display = ('email', 'get_full_name', 'is_active')
    fields = ('first_name', 'last_name', 'cpf', 'email', 'password')