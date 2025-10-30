# users/urls.py
from django.urls import path
from .views import (
    PasswordResetRequestView,
    PasswordResetConfirmView,
    PasswordCreateConfirmView
)

# Definimos um 'app_name' para que o reverse() funcione
# (ex: reverse('users:request-password-reset'))
app_name = 'users'

urlpatterns = [
    # O login (api/token/) está no medlink_core/urls.py.
    # Esta app só precisa das URLs de gestão de senha.
    
    path('request-password-reset/', PasswordResetRequestView.as_view(), name='request-password-reset'),
    path('reset-password-confirm/', PasswordResetConfirmView.as_view(), name='reset-password-confirm'),
    path('create-password-confirm/', PasswordCreateConfirmView.as_view(), name='create-password-confirm'),
]