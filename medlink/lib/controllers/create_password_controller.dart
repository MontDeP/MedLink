// medlink/lib/controllers/create_password_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medlink/services/api_service.dart';

class CreatePasswordController extends GetxController {
  final ApiService apiService = ApiService();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  // Não precisamos mais do successMessage observável, pois usaremos um dialog
  // final RxString successMessage = ''.obs;

  String uid = '';
  String token = '';

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, insira uma senha';
    }
    if (value.length < 8) {
      return 'A senha deve ter pelo menos 8 caracteres';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, confirme sua senha';
    }
    if (value != passwordController.text) {
      return 'As senhas não coincidem';
    }
    return null;
  }

  void submitCreatePassword() async {
    if (formKey.currentState!.validate()) {
      isLoading.value = true;
      errorMessage.value = ''; // Limpa mensagens de erro anteriores

      try {
        final result = await apiService.createPasswordConfirm(
          uid,
          token,
          passwordController.text,
        );

        isLoading.value = false;

        if (result['success'] == true) {
          // 👇 --- ALTERAÇÃO AQUI --- 👇
          // Em vez de definir successMessage e usar Future.delayed,
          // chamamos a função para mostrar o pop-up de sucesso.
          _showSuccessDialog(result['message'] ?? 'Senha definida com sucesso!');
          // --------------------------
        } else {
          errorMessage.value = result['message'] ?? 'Ocorreu um erro desconhecido.';
        }
      } catch (e) {
         isLoading.value = false;
         errorMessage.value = 'Erro ao conectar: ${e.toString()}';
         debugPrint("Erro em submitCreatePassword: $e");
      }
    } else {
       isLoading.value = false;
    }
  }

  // 👇 --- NOVA FUNÇÃO PARA EXIBIR O POP-UP --- 👇
  void _showSuccessDialog(String message) {
    Get.dialog(
      AlertDialog(
        title: const Text('Sucesso!'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Get.back(); // Fecha o dialog
              Get.offAllNamed('/'); // Redireciona para o login
            },
          ),
        ],
      ),
      barrierDismissible: false, // Impede fechar clicando fora
    );
  }
  // ------------------------------------------

  @override
  void onClose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}