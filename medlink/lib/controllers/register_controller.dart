import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class RegisterController {
  final ApiService _apiService = ApiService();

  Future<void> register(
    BuildContext context, {
    required String username,
    required String cpf,
    required String email,
    required String telefone,
    required String password,
    required String confirmarSenha,
  }) async {
    // Validação de campos obrigatórios
    if (username.isEmpty ||
        cpf.isEmpty ||
        email.isEmpty ||
        telefone.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Preencha todos os campos")));
      return;
    }

    // Validação de senha
    if (password != confirmarSenha) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("As senhas não coincidem")));
      return;
    }

    // Validação de CPF (simples)
    if (!_isValidCpf(cpf)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("CPF inválido")));
      return;
    }

    // Validação de email (simples)
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("E-mail inválido")));
      return;
    }

    // Validação de telefone (mínimo 10 dígitos)
    if (telefone.length < 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Telefone inválido")));
      return;
    }

    // Criar o usuário
    final user = User(
      username: username,
      cpf: cpf,
      email: email,
      telefone: telefone,
      password: password,
      tipo: "Paciente",
    );

    // Enviar para o backend
    final success = await _apiService.register(user);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cadastro realizado com sucesso!")),
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao cadastrar usuário")),
      );
    }
  }

  String _limparCPF(String cpf) {
    return cpf.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // Função simples para validar CPF
  bool _isValidCpf(String cpf) {
    final cpfLimpo = _limparCPF(cpf); // Usa a função de limpeza

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

  // Função simples para validar email
  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email);
  }
}
