// lib/views/pages/notificacoes_page.dart
import 'package:flutter/material.dart';

class NotificacoesPage extends StatelessWidget {
  const NotificacoesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        centerTitle: true,
        elevation: 2,
      ),
      body: const Center(
        child: Text(
          'Você ainda não tem notificações.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}