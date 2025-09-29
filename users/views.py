# users/views.py
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import MyTokenObtainPairSerializer

class MyTokenObtainPairView(TokenObtainPairView):
    serializer_class = MyTokenObtainPairSerializer

@api_view(['POST'])
@permission_classes([AllowAny]) # Permite que qualquer um acesse a view de registro
def register(request):
    # Extrai os dados enviados pelo Flutter
    cpf = request.data.get('cpf')
    email = request.data.get('email')
    password = request.data.get('senha') # O frontend envia 'senha'
    nome_completo = request.data.get('nome')
    telefone = request.data.get('telefone')

    # Validação básica
    if not all([cpf, email, password, nome_completo]):
        return Response(
            {"error": "Todos os campos obrigatórios devem ser preenchidos."},
            status=status.HTTP_400_BAD_REQUEST
        )

    if User.objects.filter(cpf=cpf).exists():
        return Response({"error": "Já existe um usuário com este CPF."}, status=status.HTTP_400_BAD_REQUEST)

    if User.objects.filter(email=email).exists():
        return Response({"error": "Já existe um usuário com este e-mail."}, status=status.HTTP_400_BAD_REQUEST)

    # Divide o nome completo em nome e sobrenome
    partes_nome = nome_completo.split(' ', 1)
    first_name = partes_nome[0]
    last_name = partes_nome[1] if len(partes_nome) > 1 else ''

    try:
        # Cria o usuário usando o manager customizado
        user = User.objects.create_user(
            cpf=cpf,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
            user_type='PACIENTE' # Define o tipo de usuário padrão
            # Você pode adicionar o campo 'telefone' ao seu modelo User se desejar salvá-lo
        )
        return Response({"message": "Usuário criado com sucesso!"}, status=status.HTTP_201_CREATED)

    except Exception as e:
        # Captura outros erros que possam ocorrer
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)