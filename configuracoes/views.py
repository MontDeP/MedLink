from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth import get_user_model

from .models import SystemSettings, UserSettings, SiteSettings
from .serializers import (
    SystemSettingsSerializer,
    UserSettingsSerializer,
    SiteSettingsSerializer,
)
from users.permissions import IsAdminOrReadOnly



class SystemSettingsView(APIView):
    permission_classes = [IsAuthenticated, IsAdminOrReadOnly]

    def get_object(self):
        obj, _ = SystemSettings.objects.get_or_create(pk=1)
        return obj

    def get(self, request):
        obj = self.get_object()
        return Response(SystemSettingsSerializer(obj).data)

    def patch(self, request):
        obj = self.get_object()
        ser = SystemSettingsSerializer(obj, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(ser.data, status=status.HTTP_200_OK)




class MeSettingsView(APIView):
    """
    Endpoint para o usuário autenticado acessar e atualizar
    suas próprias configurações (ex: tamanho da fonte).
    """
    permission_classes = [IsAuthenticated]

    def get_object(self, user):
        obj, _ = UserSettings.objects.get_or_create(user=user)
        return obj

    def get(self, request):
        user_settings = self.get_object(request.user)
        serializer = UserSettingsSerializer(user_settings)
        return Response(serializer.data)

    def patch(self, request):
        user_settings = self.get_object(request.user)
        serializer = UserSettingsSerializer(user_settings, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)


class SiteSettingsView(APIView):
    """
    Endpoint público para o app mobile obter informações globais
    como versão, e-mail de contato, política de privacidade e créditos.
    """
    permission_classes = [AllowAny]

    def get_object(self):
        obj, _ = SiteSettings.objects.get_or_create(pk=1)
        return obj

    def get(self, request):
        obj = self.get_object()
        serializer = SiteSettingsSerializer(obj)
        return Response(serializer.data)
