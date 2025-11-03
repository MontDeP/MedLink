from django.db import models
from django.core.exceptions import ValidationError
from django.conf import settings


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


# =====================================================
# Novos modelos para integrar com a tela simplificada do app
# =====================================================

class UserSettings(models.Model):
    FONT_SIZES = [
        ("small", "Pequena"),
        ("normal", "Normal"),
        ("large", "Grande"),
    ]
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="user_settings",
    )
    font_size = models.CharField(max_length=10, choices=FONT_SIZES, default="normal")

    def __str__(self):
        return f"UserSettings(user_id={self.user_id}, font_size={self.font_size})"


class SiteSettings(models.Model):
    """
    Configurações globais usadas pela tela de Configurações do app.
    Mantém o mesmo padrão singleton (pk=1).
    """
    app_version = models.CharField(max_length=20, default="v1.0.0")
    contact_email = models.EmailField(default="suporte@medlink.com")

    # URL ou texto/markdown da política de privacidade
    privacy_policy_url = models.URLField(blank=True, null=True)
    privacy_policy_markdown = models.TextField(blank=True)

    credits = models.TextField(blank=True, default="Equipe MedLink")
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        if not self.pk:
            self.pk = 1
        return super().save(*args, **kwargs)

    def __str__(self):
        return "SiteSettings (singleton)"
