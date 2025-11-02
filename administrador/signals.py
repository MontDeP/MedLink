# administrador/signals.py

from django.db.models.signals import post_save
from django.contrib.auth.signals import user_logged_in
from django.dispatch import receiver
from .models import LogEntry, admin 
from users.models import User
from pacientes.models import Paciente
from secretarias.models import Secretaria
from medicos.models import Medico

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created: 
        if instance.user_type == 'PACIENTE':
            Paciente.objects.create(user=instance)
            
        elif instance.user_type == 'SECRETARIA':
            Secretaria.objects.create(user=instance)
            
        elif instance.user_type == 'ADMIN':
            admin.objects.create(user=instance) # <-- Isto agora vai funcionar
            
        elif instance.user_type == 'MEDICO':
            try:
                Medico.objects.create(user=instance, crm=f"PENDENTE_{instance.id}")
            except Exception as e:
                print(f"AVISO: Falha ao criar perfil de médico automático para {instance.email}: {e}")

@receiver(user_logged_in) 
def log_user_login(sender, request, user, **kwargs):
    if user.user_type == 'ADMIN':
        LogEntry.objects.create(
            actor=user,
            action_type=LogEntry.ActionType.LOGIN,
            details=f"O utilizador {user.get_full_name()} (CPF: {user.cpf}) iniciou sessão."
        )