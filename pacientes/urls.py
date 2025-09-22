# pacientes/urls.py
from django.urls import path
from .views import PacienteListCreateView

urlpatterns = [
    path('', PacienteListCreateView.as_view(), name='lista-pacientes'),
]
