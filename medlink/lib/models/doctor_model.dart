// lib/models/doctor_model.dart (VERSÃO CORRIGIDA)

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
    // print('Doctor.fromJson: $json'); // Debug

    return Doctor(
      // Pega 'id' (da API de admin) ou 'user_id' (da API de paciente)
      id: (json['id'] ?? json['user_id'] ?? 0) as int,

      // CORREÇÃO: Adicionado 'nome_completo'
      fullName: (json['fullName'] ?? 
                 json['full_name'] ?? 
                 json['nome_completo'] ?? // <--- Chave que faltava
                 'Médico') as String,
                 
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