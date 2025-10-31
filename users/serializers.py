from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
# Importe seus modelos para poder acessá-los
from secretarias.models import Secretaria 
from medicos.models import Medico

class MyTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        token['user_type'] = user.user_type
        token['full_name'] = user.get_full_name()
        token['email'] = user.email

        try:
            if user.user_type == 'SECRETARIA':
                # Acessa o perfil e a clínica de forma segura
                if hasattr(user, 'perfil_secretaria') and user.perfil_secretaria.clinica:
                    clinica = user.perfil_secretaria.clinica
                    token['clinica_id'] = clinica.id
                    token['clinic_name'] = clinica.nome_fantasia  # Use nome_fantasia instead of nome
                else:
                    print(f"AVISO: Secretária {user.get_full_name()} sem clínica associada!")
                    token['clinica_id'] = None
                    token['clinic_name'] = "Clínica não associada"
            elif user.user_type == 'MEDICO':
                # Médico: pode ter várias clínicas
                clinicas = user.perfil_medico.clinicas.all()
                if clinicas.exists():
                    token['clinica_ids'] = [c.id for c in clinicas]
                    token['clinica_id'] = clinicas[0].id
                    token['clinic_name'] = clinicas[0].nome
        except Exception as e:
            print(f"Erro ao buscar dados da clínica: {e}")
            token['clinica_id'] = None
            token['clinic_name'] = 'Clínica não associada'

        return token