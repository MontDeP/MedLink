# notificacoes/urls.py

from django.urls import path
from . import views

urlpatterns = [
    path('', views.ListaNotificacoesView.as_view(), name='lista-notificacoes'),
    path('<int:pk>/marcar-lida/', views.MarcarNotificacaoComoLidaView.as_view(), name='marcar-notificacao-lida'),
]