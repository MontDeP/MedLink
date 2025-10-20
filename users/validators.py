# users/validators.py
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _

class DifferentFromOldPasswordValidator:
    """
    Validador que garante que a nova senha seja diferente da senha antiga.
    """
    def validate(self, password, user=None):
        if user and user.check_password(password):
            raise ValidationError(
                _("A nova senha não pode ser igual à senha antiga."),
                code='password_no_change',
            )

    def get_help_text(self):
        return _(
            "Sua nova senha não pode ser igual à sua senha atual."
        )