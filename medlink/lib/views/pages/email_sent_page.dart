import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medlink/views/pages/login.dart';

class EmailSentPage extends StatelessWidget {
  final String email;
  const EmailSentPage({Key? key, required this.email}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Cores do MedLink
    const Color medLinkBlue = Color(0xFF5BBCDC);
    const Color medLinkButton = Color(0xFF1D80A1);
    const Color medLinkButtonHover = Color(0xFF166580);

    return Scaffold(
      backgroundColor: medLinkBlue,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            // Limita a largura e altura do card
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Ícone de Sucesso
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 100,
                      color: medLinkButton, // Cor principal
                    ),
                    const SizedBox(height: 24),

                    // 2. Título
                    const Text(
                      'Verifique seu e-mail',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Texto descritivo com o e-mail
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black54, height: 1.5),
                        children: [
                          const TextSpan(
                              text: 'Enviamos as instruções de recuperação de senha para '),
                          TextSpan(
                            text: email,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const TextSpan(
                              text: '. Por favor, verifique sua caixa de entrada e spam.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 4. Botão OK (estilo do login)
                    ElevatedButton(
                      onPressed: () {
                        Get.offAll(() =>
                            const LoginPage()); // Volta tudo para a tela de login
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return medLinkButtonHover;
                          }
                          return medLinkButton;
                        }),
                        foregroundColor: WidgetStateProperty.all<Color>(
                          Colors.white,
                        ),
                        padding: WidgetStateProperty.all<EdgeInsets>(
                          const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 14,
                          ),
                        ),
                        shape: WidgetStateProperty.all<OutlinedBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        textStyle: WidgetStateProperty.all<TextStyle>(
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      child: const Text("Ok, voltar ao Login"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}