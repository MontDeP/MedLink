import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medlink/controllers/forgot_password_controller.dart';
import 'package:medlink/views/pages/login.dart';

class ForgotPasswordPage extends StatelessWidget {
  ForgotPasswordPage({Key? key}) : super(key: key);

  final ForgotPasswordController controller = Get.put(ForgotPasswordController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    // Cor de fundo e de foco, igual à sua tela de login
    const Color medLinkBlue = Color(0xFF5BBCDC);
    const Color medLinkButton = Color(0xFF1D80A1);
    const Color medLinkButtonHover = Color(0xFF166580);

    return Scaffold(
      backgroundColor: medLinkBlue,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            // Limita a largura e altura do card, igual ao login
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Logo (igual ao login)
                      SizedBox(
                        height: 80,
                        child: Image.asset(
                          'assets/images/Logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image, size: 80);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Título (estilo do login)
                      const Text(
                        "Recuperar Senha",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Insira seu e-mail abaixo para enviarmos as instruções de recuperação.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),

                      // 3. Campo de E-mail (estilo do login)
                      const Text("E-mail:"),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller.emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined),
                          hintText: "seuemail@dominio.com",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: medLinkBlue, // Cor de foco
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira seu e-mail';
                          }
                          if (!GetUtils.isEmail(value)) {
                            return 'Por favor, insira um e-mail válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // 4. Botão Enviar (estilo do login)
                      Obx(() => ElevatedButton(
                            onPressed: controller.isLoading.value
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      controller.sendRecoveryEmail();
                                    }
                                  },
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color?>(
                                      (states) {
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
                            child: controller.isLoading.value
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text("Enviar"),
                          )),
                      const SizedBox(height: 16),

                      // 5. Botão "Voltar" (estilo "Cadastrar-se")
                      Center(
                        child: TextButton(
                          onPressed: () => Get.back(), // Apenas volta
                          child: const Text(
                            "Voltar para o Login",
                            style: TextStyle(
                              color: medLinkButton,
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}