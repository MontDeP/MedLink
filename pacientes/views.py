# pacientes/views.py
from rest_framework import generics
from .models import Paciente
from .serializers import PacienteSerializer
from users.permissions import IsMedicoOrSecretaria

# View que permite listar e criar pacientes
class PacienteListCreateView(generics.ListCreateAPIView):
    queryset = Paciente.objects.all()
    serializer_class = PacienteSerializer
    permission_classes = [IsMedicoOrSecretaria]
