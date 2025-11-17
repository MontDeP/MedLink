# clinicas/urls.py (VERSÃO CORRIGIDA)

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()

router.register(r'', views.ClinicaViewSet, basename='clinica')
router.register(r'cidades', views.CidadeViewSet)
router.register(r'estados', views.EstadoViewSet)
router.register(r'tipos-clinica', views.TipoClinicaViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('<int:pk>/especialidades/', views.EspecialidadesPorClinicaView.as_view(), name='clinica-especialidades'),
]