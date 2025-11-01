// lib/models/dashboard_data_model.dart (CORRIGIDO)

// Modelo para o objeto aninhado 'proximaConsulta'
// (Este modelo agora representa QUALQUER consulta, não só a próxima)
class ProximaConsulta {
  final int id; 
  final String medico;
  final String especialidade;
  final DateTime data;
  final String local;
  final String status; 

  ProximaConsulta({
    required this.id,
    required this.medico,
    required this.especialidade,
    required this.data,
    required this.local,
    required this.status,
  });

  // Factory para converter o JSON em um objeto ProximaConsulta
  factory ProximaConsulta.fromJson(Map<String, dynamic> json) {
    return ProximaConsulta(
      id: json['id'] as int? ?? 0, // <-- Lendo o ID da consulta
      medico: json['medico'] as String? ?? 'Médico não informado',
      especialidade: json['especialidade'] as String? ?? 'Não informado',
      // O Django envia a data como uma string ISO 8601, o Dart converte
      data: DateTime.parse(json['data'] as String),
      local: json['local'] as String? ?? 'Local não informado',
      status: json['status'] as String? ?? 'pendente', // <-- Lendo o status
    );
  }
} // <--- Esta é a chave que estava faltando na minha resposta anterior

// Modelo para a resposta principal do dashboard
class DashboardData {
  final String nomePaciente;
  final ProximaConsulta? proximaConsulta; // Pode ser nulo

  // --- CAMPO ATUALIZADO ---
  final List<ProximaConsulta> todasConsultas; // Lista com todos os OBJETOS

  DashboardData({
    required this.nomePaciente,
    this.proximaConsulta,
    required this.todasConsultas, // Adicionado ao construtor
  });

  // Factory para converter o JSON na resposta completa
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    // --- LÓGICA DE PARSE ATUALIZADA ---
    // Pega a lista de OBJETOS da API
    final List<dynamic> datasDaApi =
        json['todasConsultas'] as List<dynamic>? ?? [];

    // Converte a lista de JSONs em uma lista de ProximaConsulta
    final List<ProximaConsulta> datasConvertidas = datasDaApi
        .map((consultaJson) =>
            ProximaConsulta.fromJson(consultaJson as Map<String, dynamic>))
        .toList();

    return DashboardData(
      nomePaciente: json['nomePaciente'] as String,
      // Verifica se 'proximaConsulta' não é nulo antes de converter
      proximaConsulta: json['proximaConsulta'] != null
          ? ProximaConsulta.fromJson(
              json['proximaConsulta'] as Map<String, dynamic>)
          : null,

      // --- CAMPO NOVO SENDO PREENCHIDO ---
      todasConsultas: datasConvertidas,
    );
  }
}