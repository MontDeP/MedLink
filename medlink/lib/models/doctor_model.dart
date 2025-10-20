class Doctor {
  final int id;
  final String fullName;
  final String specialty;

  Doctor({required this.id, required this.fullName, required this.specialty});

  factory Doctor.fromJson(Map<String, dynamic> json) {
    // Acessa o objeto 'user' aninhado, se a API o enviar assim
    final userJson = json['user'] as Map<String, dynamic>? ?? json;

    return Doctor(
      id: userJson['id'],
      fullName: userJson['full_name'] ?? 'Nome não informado',
      specialty: json['specialidade'] ?? 'Especialidade não informada',
    );
  }
}
