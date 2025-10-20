# users/signals.py
from django.dispatch import receiver
from django_rest_passwordreset.signals import reset_password_token_created
from django.core.mail import send_mail
from django.conf import settings

@receiver(reset_password_token_created)
def password_reset_token_created_handler(sender, instance, reset_password_token, *args, **kwargs):
    """
    Este "espião" agora tem a responsabilidade de enviar o email
    de recuperação de senha.
    """
    # Construir a URL de frontend que o usuário irá clicar.
    # Exemplo: https://medlink-app/resetar-senha?token=TOKEN123
    # A equipa de frontend dir-vos-á qual é a URL correta para usar.
    reset_url = f"https://URL_DO_FRONTEND/resetar-senha?token={reset_password_token.key}"

    # Corpo do Email
    email_subject = "Redefinição de Senha - MedLink"
    email_body = (
        f"Olá, {reset_password_token.user.get_full_name()}!\n\n"
        f"Recebemos um pedido para redefinir a sua senha para a sua conta MedLink.\n\n"
        f"Por favor, clique no link abaixo ou copie e cole no seu navegador para completar o processo:\n\n"
        f"{reset_url}\n\n"
        f"Se não pediu uma redefinição de senha, por favor ignore este email.\n\n"
        f"Atenciosamente,\nEquipe MedLink"
    )

    print("\n\n=======================================================")
    print(f"  A TENTAR ENVIAR EMAIL DE RECUPERAÇÃO REAL")
    print(f"  Para: {reset_password_token.user.email}")
    print(f"  Token: {reset_password_token.key}")
    print("=======================================================\n\n")

    # Envia o email usando a função do Django que já testámos
    send_mail(
        subject=email_subject,
        message=email_body,
        from_email=settings.EMAIL_HOST_USER,
        recipient_list=[reset_password_token.user.email]
    )