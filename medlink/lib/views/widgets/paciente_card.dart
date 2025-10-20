import 'package:flutter/material.dart';
import '../../models/paciente.dart';

class PatientCard extends StatelessWidget {
  final Paciente paciente;
  final bool selected;
  final VoidCallback onTap;

  const PatientCard({
    super.key,
    required this.paciente,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Colors.blue[100] : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(paciente.nome),
        subtitle: Text(paciente.email),
        onTap: onTap,
      ),
    );
  }
}