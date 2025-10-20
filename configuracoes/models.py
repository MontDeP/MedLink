from django.db import models
from django.core.exceptions import ValidationError

class SystemSettings(models.Model):
    # Exemplo de configurações/flags do produto
    auto_scheduling = models.BooleanField(default=False)
    email_notifications = models.BooleanField(default=True)
    two_factor_auth = models.BooleanField(default=False)

    # Ex.: quantas horas antes enviar lembrete
    reminder_hours_before = models.PositiveSmallIntegerField(default=24)  # 0..168

    updated_at = models.DateTimeField(auto_now=True)

    def clean(self):
        if not (0 <= self.reminder_hours_before <= 168):
            raise ValidationError({"reminder_hours_before": "Informe entre 0 e 168 horas."})

    def save(self, *args, **kwargs):
        # Singleton simples: força PK=1
        if not self.pk:
            self.pk = 1
        self.full_clean()
        return super().save(*args, **kwargs)

    def __str__(self):
        return "Configurações do Sistema (singleton)"
