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
    # --- NEW: Super Admin endpoint ---
    path('super/create-clinic-with-admin/', ClinicWithAdminCreateView.as_view(), name='super-create-clinic'),
    # --- NEW: Super Admin endpoint ---
    path('admin/super/create-clinic-with-admin/', ClinicWithAdminCreateView.as_view(), name='create-clinic-with-admin'),
    # --- NOVA ROTA: lista de clínicas (Super Admin) ---
    path('admin/super/clinics/', ClinicaListView.as_view(), name='super-clinic-list'),
    path('admin/super/clinics/<int:pk>/', ClinicaAdminDetailView.as_view(), name='super-clinic-detail'),  # NEW
    path('admin/super/clinics/<int:pk>/assign-admin/', AssignClinicAdminAPIView.as_view(), name='super-clinic-assign-admin'),  # NEW
    # --- NOVA ROTA: lista de clínicas (Admin) ---
    path('clinicas/', ClinicaListView.as_view(), name='admin-clinicas-list'),
    path('clinicas/create-with-admin/', ClinicWithAdminCreateView.as_view(), name='admin-clinic-create-with-admin'),
    path('clinicas/<int:pk>/', ClinicaAdminDetailView.as_view(), name='admin-clinica-detail'),
    path('clinicas/<int:pk>/assign-admin/', AssignClinicAdminAPIView.as_view(), name='admin-clinica-assign-admin'),
]