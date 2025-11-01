// lib/views/widgets/home/proxima_consulta_card.dart (COM AS MODIFICAÇÕES)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart';

class ProximaConsultaCard extends StatelessWidget {
  final ProximaConsulta? proximaConsulta;

  const ProximaConsultaCard({Key? key, this.proximaConsulta}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    if (proximaConsulta == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Nenhuma consulta agendada',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    // 👇 --- INÍCIO DA MODIFICAÇÃO: LÓGICA DE DIAS/HORAS/MINUTOS --- 👇
    // 1. Calcula a diferença
    final difference = proximaConsulta!.data.difference(DateTime.now());
    
    // 2. Define o valor e a unidade
    String valor;
    String unidade;

    if (difference.inDays > 0) {
      valor = difference.inDays.toString();
      unidade = 'dias';
    } else if (difference.inHours > 0) {
      valor = difference.inHours.toString();
      unidade = 'horas';
    } else if (difference.inMinutes > 0) {
      valor = difference.inMinutes.toString();
      unidade = 'min';
    } else {
      valor = '!';
      unidade = 'Agora';
    }
    // 👆 --- FIM DA MODIFICAÇÃO --- 👆

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próxima Consulta',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          width: screenWidth - 40,
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      proximaConsulta!.medico,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proximaConsulta!.especialidade,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${DateFormat("dd/MM/yyyy", "pt_BR").format(proximaConsulta!.data)} • ${DateFormat("HH:mm", "pt_BR").format(proximaConsulta!.data)}',
                      style:
                          const TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                    Text(
                      proximaConsulta!.local,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF0066CC), // selectedColor
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      // 👇 --- ALTERAÇÃO APLICADA --- 👇
                      (unidade == 'Agora') ? 'Consulta' : 'Faltam',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // 👇 --- ALTERAÇÃO APLICADA --- 👇
                      valor,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // 👇 --- ALTERAÇÃO APLICADA --- 👇
                      unidade,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
