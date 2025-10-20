// lib/models/paciente.dart

import 'package:medlink/models/consultas.dart' as consultas_model;

class Paciente {
  final int id;
  final int consultaId;
  final String nome;
  final DateTime horario;
  final String status;
  final String telefone;
  final String email;
  final String cpf;
  
  // --- NOVOS CAMPOS ADICIONADOS ---
  final String profissional;
  final String especialidade;

  // O histórico completo pode ser carregado depois, ao selecionar o paciente
  final List<consultas_model.Consulta> consultasHistoricas;

  Paciente({
    required this.id,
    required this.consultaId,
    required this.nome,
    required this.horario,
    required this.status,
    required this.telefone,
    required this.email,
    required this.cpf,
    required this.profissional, // Adicionado
    required this.especialidade, // Adicionado
    required this.consultasHistoricas,
  });

  factory Paciente.fromJson(Map<String, dynamic> json) {
    return Paciente(
      id: json['id'] ?? 0,
      consultaId: json['consulta_id'] ?? 0,
      nome: json['nome_completo'] ?? 'Nome não encontrado',
      email: json['email'] ?? 'E-mail não informado',
      telefone: json['telefone'] ?? 'Telefone não informado',
      cpf: json['cpf'] ?? 'CPF não informado',
      horario: DateTime.parse(json['horario']),
      status: json['status'] ?? 'N/A',

      // --- NOVOS CAMPOS SENDO LIDOS DO JSON ---
      profissional: json['profissional'] ?? 'Não informado',
      especialidade: json['especialidade'] ?? 'Não informada',
      
      consultasHistoricas: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'horario': horario.toIso8601String(),
      'status': status,
      'telefone': telefone,
      'email': email,
      'cpf': cpf,
      'profissional': profissional, // Adicionado
      'especialidade': especialidade, // Adicionado
      'consultasHistoricas': consultasHistoricas
          .map((c) => c.toJson())
          .toList(),
    };
  }
}