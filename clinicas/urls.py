from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ClinicaViewSet, CidadeViewSet, EstadoViewSet, TipoClinicaViewSet

router = DefaultRouter()
# Alterado de r'clinicas' para r'' para evitar /api/clinicas/clinicas/
router.register(r'', ClinicaViewSet, basename='clinica')
router.register(r'cidades', CidadeViewSet)
router.register(r'estados', EstadoViewSet)
router.register(r'tipos-clinica', TipoClinicaViewSet)

urlpatterns = [
    path('', include(router.urls)),
]