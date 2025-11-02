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
            # PRIORIDADE: Superuser vira ADMIN_GERAL no token
            if getattr(user, 'is_superuser', False):
                token['user_type'] = 'ADMIN_GERAL'
                token['clinica_id'] = None
                token['clinic_name'] = 'Admin Geral'
                token['is_superuser'] = True  # opcional, ajuda no debug
                return token

            # ADMIN GERAL (quando vier explicitamente do BD)
            if user.user_type == 'ADMIN_GERAL':
                token['clinica_id'] = None
                token['clinic_name'] = 'Admin Geral'
                return token

            # ADMIN de clínica (aceita ADMIN e ADMIN_CLINICA)
            if user.user_type in ['ADMIN', 'ADMIN_CLINICA']:
                if hasattr(user, 'perfil_admin') and user.perfil_admin and user.perfil_admin.clinica:
                    clinica = user.perfil_admin.clinica
                    token['clinica_id'] = clinica.id
                    token['clinic_name'] = clinica.nome_fantasia
                else:
                    token['clinica_id'] = None
                    token['clinic_name'] = "Clínica não associada"
                return token

            # SECRETARIA
            if user.user_type == 'SECRETARIA':
                if hasattr(user, 'perfil_secretaria') and user.perfil_secretaria.clinica:
                    clinica = user.perfil_secretaria.clinica
                    token['clinica_id'] = clinica.id
                    token['clinic_name'] = clinica.nome_fantasia
                else:
                    token['clinica_id'] = None
                    token['clinic_name'] = "Clínica não associada"
                return token

            # MÉDICO
            if user.user_type == 'MEDICO':
                if hasattr(user, 'perfil_medico'):
                    clinicas = user.perfil_medico.clinicas.all()
                    if clinicas:
                        token['clinica_ids'] = [c.id for c in clinicas]
                        token['clinica_id'] = clinicas[0].id
                        token['clinic_name'] = clinicas[0].nome_fantasia
                    else:
                        token['clinica_ids'] = []
                        token['clinica_id'] = None
                        token['clinic_name'] = "Clínica não associada"
                return token

            # PACIENTE
            if user.user_type == 'PACIENTE':
                if hasattr(user, 'perfil_paciente') and user.perfil_paciente.clinica:
                    clinica = user.perfil_paciente.clinica
                    token['clinica_id'] = clinica.id
                    token['clinic_name'] = clinica.nome_fantasia
                else:
                    token['clinica_id'] = None
                    token['clinic_name'] = "Clínica não associada"
                return token

            # Fallback
            token['clinica_id'] = None
            token['clinic_name'] = "Clínica não associada"

        except Exception as e:
            print(f"Erro ao processar dados da clínica para o token: {e}")
            token['clinica_id'] = None
            token['clinic_name'] = "Erro ao carregar clínica"

        return token