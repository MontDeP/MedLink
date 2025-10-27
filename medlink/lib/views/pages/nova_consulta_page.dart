// lib/views/pages/nova_consulta_page.dart
import 'package:flutter/material.dart';

class NovaConsultaPage extends StatelessWidget {
  const NovaConsultaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Consulta'),
        backgroundColor: const Color(0xFF317714),
      ),
      body: const Center(
        child: Text(
          'Aqui você irá criar uma nova consulta.',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
      backgroundColor: const Color(0xFFF9F9F9),
    );
  }
}