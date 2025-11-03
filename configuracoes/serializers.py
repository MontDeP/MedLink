from rest_framework import serializers
from .models import SystemSettings, UserSettings, SiteSettings



class SystemSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemSettings
        fields = [
            "auto_scheduling",
            "email_notifications",
            "two_factor_auth",
            "reminder_hours_before",
            "updated_at",
        ]
        read_only_fields = ["updated_at"]

    def validate_reminder_hours_before(self, value):
        """
        Move a validação do models.py para o serializers.py
        para que o DRF retorne 400 Bad Request corretamente.
        """
        if not (0 <= value <= 168):
            raise serializers.ValidationError("Informe entre 0 e 168 horas.")
        return value



class UserSettingsSerializer(serializers.ModelSerializer):
    """
    Preferências individuais do usuário (ex: tamanho da fonte).
    """
    class Meta:
        model = UserSettings
        fields = ["font_size"]


class SiteSettingsSerializer(serializers.ModelSerializer):
    """
    Configurações globais do app (usadas na tela de Configurações).
    """
    class Meta:
        model = SiteSettings
        fields = [
            "app_version",
            "contact_email",
            "privacy_policy_url",
            "privacy_policy_markdown",
            "credits",
            "updated_at",
        ]
        read_only_fields = ["updated_at"]
