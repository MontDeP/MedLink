// lib/views/widgets/home/home_header.dart (NOVO ARQUIVO)
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String nomePaciente;

  const HomeHeader({Key? key, required this.nomePaciente}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Ícone de fallback (como corrigimos no passo anterior)
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey.shade300,
          child: Icon(
            Icons.person,
            size: 40,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Olá,',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              nomePaciente,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}