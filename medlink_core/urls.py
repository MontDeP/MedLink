"""
URL configuration for medlink_core project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include 

from users.views import MyTokenObtainPairView
from rest_framework_simplejwt.views import TokenRefreshView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/token/', MyTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    path('api/pacientes/', include('pacientes.urls')),
    path('api/agendamentos/', include('agendamentos.urls')),
    path('api/password_reset/', include('django_rest_passwordreset.urls', namespace='password_reset')),
    path('api/medicos/', include('medicos.urls')),
    path('api/users/', include('users.urls')),
    path('api/secretarias/', include('secretarias.urls')),
    path('api/clinicas/', include('clinicas.urls')),
    path('api/admin/', include('administrador.urls')),
    path('api/admin/', include('configuracoes.urls')),  # se quiser manter essa rota também
    path('api/', include('administrador.urls')),  # adiciona rotas do app administrador
]
