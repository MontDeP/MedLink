from rest_framework import viewsets
from .models import Clinica, Cidade, Estado, TipoClinica
from .serializers import ClinicaSerializer, CidadeSerializer, EstadoSerializer, TipoClinicaSerializer
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework import permissions
from medicos.models import Medico

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

class ClinicaDetailView(APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request, pk):
        try:
            # Verifica se o usuário tem acesso a esta clínica
            if request.user.user_type == 'SECRETARIA':
                clinica = request.user.perfil_secretaria.clinica
                if clinica.id != pk:
                    return Response(
                        {"error": "Acesso negado a esta clínica"}, 
                        status=status.HTTP_403_FORBIDDEN
                    )
            
            clinica = Clinica.objects.get(pk=pk)
            serializer = ClinicaSerializer(clinica)
            return Response(serializer.data)
            
        except Clinica.DoesNotExist:
            return Response(
                {"error": "Clínica não encontrada"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        

class EspecialidadesPorClinicaView(APIView):
    """
    View para listar as especialidades únicas dos médicos
    associados a uma clínica específica.
    """
    permission_classes = [permissions.IsAuthenticated] # Garante que o usuário esteja logado

    def get(self, request, pk=None):
        try:
            # Garante que a clínica existe
            clinica = Clinica.objects.get(pk=pk)
        except Clinica.DoesNotExist:
            return Response({"error": "Clínica não encontrada."}, status=404)

        # Filtra os médicos que pertencem a esta clínica (M2M)
        # Pega a lista de suas especialidades
        # '.distinct()' garante que cada especialidade apareça apenas uma vez
        especialidades = Medico.objects.filter(clinicas=clinica) \
                                       .values_list('especialidade', flat=True) \
                                       .distinct()
                                       
        # Opcional: Formatar os nomes (ex: 'CLINICA_GERAL' -> 'Clínica Geral')
        # Por simplicidade, vamos retornar os valores crus por enquanto
        # Para formatar, você usaria Medico.EspecialidadeChoices.labels
        
        return Response(list(especialidades))