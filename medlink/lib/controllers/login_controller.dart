// lib/controllers/login_controller.dart

import 'dart:convert';
import 'package:http/http.dart' as http; // Mantida sua importação
import '../services/api_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class LoginController {
  final ApiService _apiService = ApiService();

  String _limparCPF(String cpf) {
    return cpf.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // Mantida a sua função de validação de CPF completa
  bool validarCPF(String cpf) {
    final cpfLimpo = _limparCPF(cpf);
    if (cpfLimpo.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpfLimpo)) return false;

    List<int> numbers = cpfLimpo.split('').map(int.parse).toList();
    int soma1 = 0;
    for (int i = 0; i < 9; i++) {
      soma1 += numbers[i] * (10 - i);
    }
    int digito1 = (soma1 * 10) % 11;
    if (digito1 == 10) digito1 = 0;
    if (digito1 != numbers[9]) return false;

    int soma2 = 0;
    for (int i = 0; i < 10; i++) {
      soma2 += numbers[i] * (11 - i);
    }
    int digito2 = (soma2 * 10) % 11;
    if (digito2 == 10) digito2 = 0;
    if (digito2 != numbers[10]) return false;

    return true;
  }

  // Mantida a sua função de login completa e mais robusta
  /// Tenta fazer o login e, se bem-sucedido, retorna um mapa com os tokens e o tipo de usuário.
  /// Retorna nulo em caso de falha.
  Future<Map<String, dynamic>?> login(String cpf, String senha) async {
    final cpfLimpo = _limparCPF(cpf);

    final response = await _apiService.login(cpfLimpo, senha);

    if (response != null && response['success'] == true) {
      print(
        'Login bem-sucedido para o tipo de usuário: ${response['user_type']}',
      );
      return response;
    } else {
      print(
        'Falha no login: ${response?['status_code'] ?? response?['error'] ?? 'Erro desconhecido'}',
      );
      return null;
    }
  }
}
