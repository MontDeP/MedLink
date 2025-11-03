from rest_framework import serializers
from .models import SystemSettings

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
            # Levanta a ValidationError do DRF
            raise serializers.ValidationError(("Informe entre 0 e 168 horas."))
        return value