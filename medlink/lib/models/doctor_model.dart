class Doctor {
  final int id;
  final String fullName;
  final String? especialidade;
  final String? crm;

  Doctor({
    required this.id,
    required this.fullName,
    this.especialidade,
    this.crm,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    print('Doctor.fromJson: $json'); // Debug

    return Doctor(
      id: (json['id'] ?? json['user_id'] ?? 0) as int,
      fullName: (json['fullName'] ?? json['full_name'] ?? 'Médico') as String,
      especialidade: json['especialidade'] as String?,
      crm: json['crm'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'especialidade': especialidade,
      'crm': crm,
    };
  }
}
