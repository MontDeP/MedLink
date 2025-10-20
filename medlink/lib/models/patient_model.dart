// lib/models/patient_model.dart

class Patient {
  final int id;
  final String fullName;

  Patient({required this.id, required this.fullName});

  factory Patient.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? json;
    return Patient(
      id: userJson['id'],
      fullName: userJson['nome_completo'] ?? 'Nome não informado',
    );
  }
}
