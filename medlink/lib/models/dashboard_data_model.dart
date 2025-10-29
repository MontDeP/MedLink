// lib/models/dashboard_data_model.dart

// Modelo para o objeto aninhado 'proximaConsulta'
class ProximaConsulta {
  final String medico;
  final String especialidade;
  final DateTime data;
  final String local;

  ProximaConsulta({
    required this.medico,
    required this.especialidade,
    required this.data,
    required this.local,
  });

  // Factory para converter o JSON em um objeto ProximaConsulta
  factory ProximaConsulta.fromJson(Map<String, dynamic> json) {
    return ProximaConsulta(
      medico: json['medico'] as String,
      especialidade: json['especialidade'] as String,
      // O Django envia a data como uma string ISO 8601, o Dart converte
      data: DateTime.parse(json['data'] as String),
      local: json['local'] as String,
    );
  }
}

// Modelo para a resposta principal do dashboard
class DashboardData {
  final String nomePaciente;
  final ProximaConsulta? proximaConsulta; // Pode ser nulo

  DashboardData({
    required this.nomePaciente,
    this.proximaConsulta,
  });

  // Factory para converter o JSON na resposta completa
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      nomePaciente: json['nomePaciente'] as String,
      // Verifica se 'proximaConsulta' não é nulo antes de converter
      proximaConsulta: json['proximaConsulta'] != null
          ? ProximaConsulta.fromJson(json['proximaConsulta'] as Map<String, dynamic>)
          : null,
    );
  }
}