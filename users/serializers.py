from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
# Importe seus modelos para poder acessá-los
from secretarias.models import Secretaria 
from medicos.models import Medico

class MyTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        # Adiciona os dados customizados que já existiam
        token['user_type'] = user.user_type
        token['full_name'] = user.get_full_name()
        token['email'] = user.email

        # --- LÓGICA CORRIGIDA PARA CLÍNICA ---
        try:
            if user.user_type == 'SECRETARIA':
                # Secretária: uma clínica
                clinica_id = getattr(user.perfil_secretaria.clinica, 'id', None)
                token['clinica_id'] = clinica_id
                token['clinic_name'] = user.perfil_secretaria.clinica.nome  # Add clinic name
            elif user.user_type == 'MEDICO':
                # Médico: pode ter várias clínicas
                clinicas = getattr(user.perfil_medico, 'clinicas', None)
                if clinicas:
                    token['clinica_ids'] = [c.id for c in clinicas.all()]
                    # Para compatibilidade, também envia o primeiro clinica_id
                    token['clinica_id'] = token['clinica_ids'][0] if token['clinica_ids'] else None
                else:
                    token['clinica_ids'] = []
                    token['clinica_id'] = None
            else:
                token['clinica_id'] = None
        except Exception:
            token['clinica_id'] = None
            token['clinica_ids'] = []

        # --- FIM DA LÓGICA CORRIGIDA ---
        return token