# users/serializers.py

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import User # Garanta que o caminho para seu modelo User está correto

# -------------------------------------------------------------------
# SEU SERIALIZER: Para customizar o token no LOGIN (Já está perfeito)
# -------------------------------------------------------------------
class MyTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        # Chama o método original para obter o token básico
        token = super().get_token(user)

        # Adiciona nossos dados customizados ao payload do token
        # O app Flutter poderá ler esses dados
        token['user_type'] = user.user_type
        token['full_name'] = user.get_full_name()
        token['email'] = user.email

        return token


# -------------------------------------------------------------------
# NOVO SERIALIZER: Para traduzir a LISTA DE USUÁRIOS para a API
# -------------------------------------------------------------------
class UserSerializer(serializers.ModelSerializer):
    # Campo extra para combinar first_name e last_name
    full_name = serializers.CharField(source='get_full_name', read_only=True)

    class Meta:
        model = User
        # Defina os campos que você quer que a API retorne na listagem.
        # Estes devem corresponder aos campos que o Flutter espera.
        fields = [
            'id', 
            'cpf', 
            'email',
            'full_name', # Nome completo
            'user_type', 
            'is_active', 
            'last_login',
            # Adicione aqui outros campos que a tela de admin precisa, como 'specialty'
        ]