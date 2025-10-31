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
                if hasattr(user, 'perfil_secretaria') and user.perfil_secretaria.clinica:
                    clinica = user.perfil_secretaria.clinica
                    token['clinica_id'] = clinica.id
                    token['clinic_name'] = getattr(clinica, 'nome_fantasia', None) or ''
                else:
                    token['clinica_id'] = None
                    token['clinic_name'] = "Clínica não associada"
            elif user.user_type == 'MEDICO':
                clinicas = user.perfil_medico.clinicas.all() if hasattr(user, 'perfil_medico') else []
                if clinicas:
                    token['clinica_ids'] = [c.id for c in clinicas]
                    token['clinica_id'] = clinicas[0].id
                    token['clinic_name'] = getattr(clinicas[0], 'nome_fantasia', None) or ''
                else:
                    token['clinica_ids'] = []
                    token['clinica_id'] = None
                    token['clinic_name'] = "Clínica não associada"
            elif user.user_type == 'PACIENTE':
                # Paciente: envia a clínica vinculada ao perfil do paciente
                if hasattr(user, 'perfil_paciente') and user.perfil_paciente.clinica:
                    clinica = user.perfil_paciente.clinica
                    token['clinica_id'] = clinica.id
                    token['clinic_name'] = getattr(clinica, 'nome_fantasia', None) or ''
                else:
                    token['clinica_id'] = None
                    token['clinic_name'] = "Clínica não associada"
            else:
                token['clinica_id'] = None
                token['clinic_name'] = "Clínica não associada"
        except Exception as e:
            print(f"Erro ao processar dados da clínica para o token: {e}")
            token['clinica_id'] = None
            token['clinic_name'] = "Erro ao carregar clínica"

        return token