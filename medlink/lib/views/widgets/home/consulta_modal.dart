// lib/views/widgets/home/consulta_modal.dart (NOVO ARQUIVO)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart';

// O método _showConsultaModal agora é uma função pública neste arquivo
void showConsultaModal(
    BuildContext context, DateTime dia, List<ProximaConsulta> consultasDoDia) {
  
  final Color selectedColor = const Color(0xFF0066CC); // Cor do dia Selecionado

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. CABEÇALHO (Título + Botão X) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Consultas - ${DateFormat('dd/MM/yyyy', 'pt_BR').format(dia)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: selectedColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),

              // --- 2. DIVISOR ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Divider(height: 1, color: Colors.black12),
              ),

              // --- 3. LISTA DE CONSULTAS ---
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: consultasDoDia.length,
                    itemBuilder: (context, index) {
                      final consulta = consultasDoDia[index];

                      // --- Card de Item de Consulta ---
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Dr. ${consulta.medico}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              consulta.especialidade.toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                            const Divider(height: 20, thickness: 0.5),
                            Text(
                              'Horário: ${DateFormat('HH:mm', 'pt_BR').format(consulta.data)}',
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Local: ${consulta.local}',
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black87),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}