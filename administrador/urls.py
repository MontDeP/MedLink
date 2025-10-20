# administrador/urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import *

# O router cria automaticamente as rotas do CRUD para o ViewSet
# GET /api/admin/users/ -> Listar
# POST /api/admin/users/ -> Criar
# GET /api/admin/users/{id}/ -> Detalhar
# etc.
router = DefaultRouter()
router.register(r'users', AdminUserViewSet, basename='admin-user')
router.register(r'logs', LogEntryViewSet, basename='admin-log')

urlpatterns = [
    path('', include(router.urls)),
    path('stats/', AdminDashboardStatsAPIView.as_view(), name='admin-dashboard-stats'),
]