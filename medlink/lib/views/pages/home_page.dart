// lib/views/pages/home_page.dart

import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MedLink - Início'),
        backgroundColor: const Color(0xFF1D80A1), // Cor consistente com o tema
        elevation: 2,
        actions: [
          Tooltip(
            message: 'Sair',
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                // Navega para a tela de login e remove todas as outras telas da pilha
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 100,
            ),
            const SizedBox(height: 24),
            const Text(
              'Login Realizado com Sucesso!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Seja bem-vindo(a) ao sistema MedLink.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}