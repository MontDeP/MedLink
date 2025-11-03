# users/urls.py
from django.urls import path
from django.contrib.auth import views as auth_views
from . import views
from .views import (
    MyTokenObtainPairView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    PasswordCreateConfirmView,
    UserManagementView
)
app_name = 'users'

urlpatterns = [
    # O login (api/token/) está no medlink_core/urls.py.
    # Esta app só precisa das URLs de gestão de senha.
    
    path('request-password-reset/', PasswordResetRequestView.as_view(), name='request-password-reset'),
    path('reset-password-confirm/', PasswordResetConfirmView.as_view(), name='reset-password-confirm'),
    path('create-password-confirm/', PasswordCreateConfirmView.as_view(), name='create-password-confirm'),
    path('admin/users/', UserManagementView.as_view(), name='admin-users-list'),
    path('admin/users/<int:pk>/', UserManagementView.as_view(), name='admin-users-detail'),
]