// lib/views/pages/create_password_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medlink/controllers/create_password_controller.dart'; // Importa o controller correto

class CreatePasswordPage extends StatelessWidget {
  final String uid;
  final String token;

  CreatePasswordPage({
    Key? key,
    required this.uid,
    required this.token,
  }) : super(key: key) {
    // Injeta o controller e já passa os parâmetros para ele
    final controller = Get.put(CreatePasswordController());
    controller.uid = uid;
    controller.token = token;
  }

  @override
  Widget build(BuildContext context) {
    // Busca o controller que acabamos de injetar
    final CreatePasswordController controller = Get.find();

    // Estilos consistentes com sua tela de reset
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
                  key: controller.formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 80,
                        child: Image.asset(
                          'assets/images/Logo.png', //
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Bem-vindo(a), crie sua senha!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Por favor, insira e confirme sua nova senha de acesso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),

                      // Campo "Nova Senha"
                      const Text("Nova Senha:"),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller.passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          hintText: "********",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: controller.validatePassword,
                      ),
                      const SizedBox(height: 16),

                      // Campo "Confirmar Nova Senha"
                      const Text("Confirmar Senha:"),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller.confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          hintText: "********",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: controller.validateConfirmPassword,
                      ),
                      const SizedBox(height: 24),

                      // Mensagem de Erro (exibida acima do botão)
                      Obx(() {
                        if (controller.errorMessage.value.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              controller.errorMessage.value,
                              style: TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        // 👇 REMOVIDO: A verificação de successMessage não é mais necessária aqui
                        // if (controller.successMessage.value.isNotEmpty) { ... }
                        return SizedBox.shrink(); // Sem mensagem, não ocupa espaço
                      }),

                      // Botão Salvar
                      Obx(() => ElevatedButton(
                            // Desabilita apenas se estiver carregando
                            onPressed: controller.isLoading.value
                                ? null
                                : () {
                                    controller.submitCreatePassword();
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
                                // 👇 REMOVIDO: A verificação de successMessage não é mais necessária aqui
                                : const Text("Definir Senha e Acessar"),
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