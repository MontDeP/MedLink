from rest_framework import viewsets
from .models import Clinica, Cidade, Estado, TipoClinica
from .serializers import ClinicaSerializer, CidadeSerializer, EstadoSerializer, TipoClinicaSerializer

class EstadoViewSet(viewsets.ModelViewSet):
    queryset = Estado.objects.all()
    serializer_class = EstadoSerializer

class CidadeViewSet(viewsets.ModelViewSet):
    queryset = Cidade.objects.all()
    serializer_class = CidadeSerializer

class TipoClinicaViewSet(viewsets.ModelViewSet):
    queryset = TipoClinica.objects.all()
    serializer_class = TipoClinicaSerializer

class ClinicaViewSet(viewsets.ModelViewSet):
    queryset = Clinica.objects.all()
    serializer_class = ClinicaSerializer
    # Adicionar permissões aqui no futuro para restringir quem pode criar/editar