import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medlink/services/api_service.dart';
import 'package:medlink/views/pages/email_sent_page.dart';

class ForgotPasswordController extends GetxController {
  final emailController = TextEditingController();
  var isLoading = false.obs;

  // 👇 ADICIONE ESTA LINHA para instanciar o serviço
  final ApiService _apiService = ApiService();

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }

  Future<void> sendRecoveryEmail() async {
    try {
      isLoading(true);
      String email = emailController.text.trim();

      // 👇 ALTERE ESTA LINHA
      // Antes: final result = await ApiService.requestPasswordReset(email);
      // Agora:
      final result = await _apiService.requestPasswordReset(email);

      isLoading(false);

      if (result['success']) {
        // Sucesso: Navega para a tela de confirmação
        Get.off(() => EmailSentPage(email: email)); // Usa Get.off para substituir a tela
      } else {
        // Erro: Mostra snackbar com a mensagem do backend
        Get.snackbar(
          'Erro ao enviar e-mail',
          result['message'],
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
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