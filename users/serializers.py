# users/serializers.py
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

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
    