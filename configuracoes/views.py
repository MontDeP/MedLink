from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from .models import SystemSettings
from .serializers import SystemSettingsSerializer
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
