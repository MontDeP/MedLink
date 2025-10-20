// lib/controllers/reset_password_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medlink/services/api_service.dart';
import 'package:medlink/views/pages/login.dart';

class ResetPasswordController extends GetxController {
  // Controladores para os campos de texto da página
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  
  // Variáveis reativas para o estado da UI
  var isLoading = false.obs;
  var isPasswordObscure = true.obs;
  var isConfirmObscure = true.obs;

  // Instância do nosso serviço de API
  final ApiService _apiService = ApiService();

  @override
  void onClose() {
    // Limpa os controladores quando a página é fechada
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  // Funções para alternar a visibilidade das senhas
  void togglePasswordVisibility() => isPasswordObscure.value = !isPasswordObscure.value;
  void toggleConfirmVisibility() => isConfirmObscure.value = !isConfirmObscure.value;

  // Função principal que envia a nova senha
  Future<void> confirmPasswordReset(String uid, String token) async {
    try {
      isLoading(true); // Ativa o loading
      String password = passwordController.text;

      // Chama a função no ApiService (que vamos criar no próximo passo)
      final result = await _apiService.confirmPasswordReset(uid, token, password);

      isLoading(false); // Desativa o loading

      if (result['success']) {
        // Sucesso: Mostra um pop-up e envia para o Login
        Get.defaultDialog(
          title: "Senha Redefinida!",
          middleText: "Sua senha foi alterada com sucesso. Você já pode fazer o login.",
          textConfirm: "Ir para Login",
          confirmTextColor: Colors.white,
          onConfirm: () => Get.offAll(() => const LoginPage()), // Limpa a pilha de rotas
        );
      }  else {
        Get.defaultDialog(
          title: "Erro ao redefinir senha",
          middleText: result['message'], // Mostra a mensagem do back-end
          textCancel: "OK", // Um botão para fechar
          cancelTextColor: Colors.blue,
          onCancel: () => Get.back(), // Apenas fecha o pop-up
        );
      }
    } catch (e) {
      isLoading(false);
      Get.snackbar(
        'Erro',
        'Ocorreu um problema inesperado. Tente novamente.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}