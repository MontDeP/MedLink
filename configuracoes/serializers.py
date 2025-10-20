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
