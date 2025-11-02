// lib/models/especialidade_model.dart
class Especialidade {
  final String key; // Ex: "CARDIOLOGIA"
  final String label; // Ex: "Cardiologia"

  Especialidade({required this.key, required this.label});

  factory Especialidade.fromJson(Map<String, dynamic> json) {
    return Especialidade(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
    );
  }
}