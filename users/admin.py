from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    model = User
    list_display = ("cpf", "email", "first_name", "last_name", "user_type", "is_staff")
    fieldsets = (
        (None, {"fields": ("cpf", "email", "password", "user_type")}),
        ("Informações pessoais", {"fields": ("first_name", "last_name")}),
        ("Permissões", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Datas importantes", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("cpf", "email", "password1", "password2", "user_type", "is_staff", "is_active"),
        }),
    )
    search_fields = ("cpf", "email")
    ordering = ("cpf",)
