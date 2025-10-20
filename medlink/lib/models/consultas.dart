// lib/models/consultas.dart (VERSÃO ATUALIZADA)

class Consulta {
  final int id;
  final DateTime horario;
  final String status;
  final String especialidade;
  final String profissional;
  final String? anotacaoConteudo; // <-- NOVO CAMPO ADICIONADO

  Consulta({
    required this.id,
    required this.horario,
    required this.status,
    required this.especialidade,
    required this.profissional,
    this.anotacaoConteudo, // <-- Adicionado ao construtor
  });

  factory Consulta.fromJson(Map<String, dynamic> json) {
    final medicoDetalhes = json['medico_detalhes'] as Map<String, dynamic>?;

    return Consulta(
      id: json['id'] ?? 0,
      horario: DateTime.parse(json['data_hora']),
      status: json['status_atual'] ?? 'N/A',
      especialidade: medicoDetalhes?['especialidade'] ?? 'Não informada',
      profissional: medicoDetalhes?['nome_completo'] ?? 'Não informado',
      anotacaoConteudo: json['anotacao_conteudo'], // <-- Lendo o novo campo
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data_hora': horario.toIso8601String(),
      'status_atual': status,
      'especialidade': especialidade,
      'profissional': profissional,
      'anotacao_conteudo': anotacaoConteudo,
    };
  }
}