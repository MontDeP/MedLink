// lib/models/clinica_model.dart
class Clinica {
  final int id;
  final String nomeFantasia;

  Clinica({required this.id, required this.nomeFantasia});

  factory Clinica.fromJson(Map<String, dynamic> json) {
    return Clinica(
      id: json['id'],
      nomeFantasia: json['nome_fantasia'],
    );
  }
}