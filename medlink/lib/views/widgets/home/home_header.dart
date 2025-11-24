// lib/views/widgets/home/home_header.dart (NOVO ARQUIVO)
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String nomePaciente;

  const HomeHeader({Key? key, required this.nomePaciente}) : super(key: key);

  // Função helper para extrair as iniciais (copiada da lógica do ProfileBody, simplificada)
  String _getInitials(String fullName) {
    if (fullName.isEmpty) return 'P'; 
    
    List<String> parts = fullName.trim().split(RegExp(r'\s+'));
    String initials = '';

    // Pega a primeira letra do primeiro nome
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials += parts[0][0].toUpperCase();
    }

    // Pega a primeira letra do último nome
    if (parts.length > 1) {
      String lastName = parts.last;
      if (lastName.length > 1) {
        initials += lastName[0].toUpperCase();
      }
    }
    
    return initials.length >= 2 ? initials.substring(0, 2) : initials;
  }

  @override
  Widget build(BuildContext context) {
    final String initials = _getInitials(nomePaciente);
    
    return Row(
      children: [
        // Substituindo o CircleAvatar estático pelo avatar de iniciais
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue.shade700, // Cor de fundo consistente
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 24, // Tamanho da fonte ajustado para o raio 30
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Olá,',
              style: TextStyle(fontSize: 16, color: Colors.white70), // Ajustei a cor para ficar melhor no fundo azul
            ),
            Text(
              nomePaciente,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // Cor do nome
            ),
          ],
        ),
      ],
    );
  }
}