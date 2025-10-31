# medicos/models.py
from django.db import models
from django.conf import settings
from clinicas.models import Clinica
from users.models import User
from django.utils.translation import gettext_lazy as _

class MedicoManager(models.Manager):
    """Normaliza clinica/clinicas/clinica_id/clinicaId e aplica no M2M após criar."""
    def _to_ids(self, value):
        if value is None:
            return []
        seq = value if isinstance(value, (list, tuple, set)) else [value]
        out = []
        for v in seq:
            try:
                out.append(int(getattr(v, 'id', v)))
            except Exception:
                continue
        return out

    def create(self, **kwargs):
        # coleta aliases antes de criar
        collected = []
        for key in ['clinicas', 'clinica', 'clinica_id', 'clinicaId', 'clinic_id']:
            if key in kwargs:
                collected += self._to_ids(kwargs.pop(key))
        # cria sem kwargs inválidos
        instance = super().create(**kwargs)
        # aplica M2M após persistir
        if collected:
            instance.clinicas.set(Clinica.objects.filter(id__in=collected))
        return instance

class Medico(models.Model):
    """
    Modelo de Perfil para o Médico, ligado ao modelo User principal.
    """
    # Enum com opções predefinidas para a especialidade, garantindo consistência.
    class EspecialidadeChoices(models.TextChoices):
        CARDIOLOGIA = 'CARDIOLOGIA', _('Cardiologia')
        DERMATOLOGIA = 'DERMATOLOGIA', _('Dermatologia')
        GINECOLOGIA = 'GINECOLOGIA', _('Ginecologia')
        ORTOPEDIA = 'ORTOPEDIA', _('Ortopedia')
        PEDIATRIA = 'PEDIATRIA', _('Pediatria')
        CLINICA_GERAL = 'CLINICA_GERAL', _('Clínica Geral')
        # Adicione outras especialidades conforme necessário

    # Relação 1-para-1 com o modelo User. É a chave primária da tabela.
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='perfil_medico' # Nome explícito para o acesso reverso
    )

    # CRM único para garantir que não haja dois médicos com o mesmo registro.
    crm = models.CharField(_("CRM"), max_length=20, unique=True)

    # Campo de escolha controlada para a especialidade.
    especialidade = models.CharField(
        max_length=50,
        choices=EspecialidadeChoices.choices,
        default=EspecialidadeChoices.CLINICA_GERAL
    )

    # Troque ForeignKey por ManyToManyField para multi-clínica:
    clinicas = models.ManyToManyField(
        Clinica,
        related_name='medicos',
        blank=True
    )

    # Campo para data de nascimento, opcional.
    data_nascimento = models.DateField(_("Data de Nascimento"), null=True, blank=True)

    objects = MedicoManager()  # <<< usa o manager que normaliza clinicas

    class Meta:
        verbose_name = "Médico"
        verbose_name_plural = "Médicos"
        ordering = ['user__first_name', 'user__last_name']

    def __str__(self):
        return f"Dr(a). {self.user.get_full_name()} (CRM: {self.crm})"
    

class MedicoUser(User):
    """Modelo Proxy para tratar utilizadores do tipo Médico no admin."""
    class Meta:
        proxy = True
        verbose_name = 'Médico (Utilizador)'
        verbose_name_plural = 'Médicos (Utilizadores)'