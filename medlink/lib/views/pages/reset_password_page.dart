// lib/views/pages/reset_password_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medlink/controllers/reset_password_controller.dart';

class ResetPasswordPage extends StatelessWidget {
  final String uid;
  final String token;

  // O Construtor recebe o UID e o Token da rota que definimos no main.dart
  ResetPasswordPage({
    Key? key,
    required this.uid,
    required this.token,
  }) : super(key: key);

  // Instancia o controller que vamos criar no próximo passo
  final ResetPasswordController controller = Get.put(ResetPasswordController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    // Estilos consistentes com sua tela de login
    const Color medLinkBlue = Color(0xFF5BBCDC);
    const Color medLinkButton = Color(0xFF1D80A1);
    const Color medLinkButtonHover = Color(0xFF166580);

    return Scaffold(
      backgroundColor: medLinkBlue,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
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
                      SizedBox(
                        height: 80,
                        child: Image.asset(
                          'assets/images/Logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Crie sua Nova Senha",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Por favor, insira e confirme sua nova senha.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                       '⚠️ Por segurança, você não pode usar a mesma senha anterior.',
                       textAlign: TextAlign.center,
                       style: TextStyle(
                       fontSize: 14,
                       color: Colors.redAccent,
                       fontWeight: FontWeight.w500,
                        ),
                     ),

                      const SizedBox(height: 24),

                      // Campo "Nova Senha"
                      const Text("Nova Senha:"),
                      const SizedBox(height: 8),
                      Obx(() => TextFormField(
                            controller: controller.passwordController,
                            obscureText: controller.isPasswordObscure.value,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  controller.isPasswordObscure.value
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: controller.togglePasswordVisibility,
                              ),
                              hintText: "********",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira uma senha';
                              }
                              if (value.length < 8) {
                                return 'A senha deve ter no mínimo 8 caracteres';
                              }
                              return null;
                            },
                          )),
                      const SizedBox(height: 16),

                      // Campo "Confirmar Nova Senha"
                      const Text("Confirmar Senha:"),
                      const SizedBox(height: 8),
                      Obx(() => TextFormField(
                            controller: controller.confirmPasswordController,
                            obscureText: controller.isConfirmObscure.value,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  controller.isConfirmObscure.value
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: controller.toggleConfirmVisibility,
                              ),
                              hintText: "********",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, confirme sua senha';
                              }
                              if (value != controller.passwordController.text) {
                                return 'As senhas não coincidem';
                              }
                              return null;
                            },
                          )),
                      const SizedBox(height: 24),

                      // Botão Salvar
                      Obx(() => ElevatedButton(
                            onPressed: controller.isLoading.value
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      // Passa o UID e o Token para o controller
                                      controller.confirmPasswordReset(uid, token);
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
                                : const Text("Salvar Nova Senha"),
                          )),
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