from django.urls import path
from .views import (
    SystemSettingsView,
    MeSettingsView,
    SiteSettingsView,
)

urlpatterns = [
    # Configurações administrativas do sistema (global)
    path("settings/", SystemSettingsView.as_view(), name="system_settings"),

    # Configurações pessoais do usuário autenticado
    path("me/settings/", MeSettingsView.as_view(), name="me_settings"),

    # Configurações públicas do app (versão, e-mail, política, créditos)
    path("site/settings/", SiteSettingsView.as_view(), name="site_settings"),
]
