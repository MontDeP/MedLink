# users/urls.py

from django.urls import path
from django.contrib.auth import views as auth_views
from .views import UserListView
from . import views

app_name = 'users'

urlpatterns = [
    path('login/', auth_views.LoginView.as_view(
        template_name='users/login.html',
        redirect_authenticated_user=True # Redireciona se o usuário já estiver logado
    ), name='login'),
    
    path('logout/', auth_views.LogoutView.as_view(), name='logout'),

    path('register/', views.register, name='register'),
]