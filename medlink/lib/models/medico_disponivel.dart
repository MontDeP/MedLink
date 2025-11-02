// lib/models/medico_disponivel.dart
class MedicoDisponivel {
  final int userId;
  final String nomeCompleto;
  final String especialidadeKey; // Ex: 'CARDIOLOGIA'
  final String especialidadeLabel; // Ex: 'Cardiologia'

  MedicoDisponivel({
    required this.userId,
    required this.nomeCompleto,
    required this.especialidadeKey,
    required this.especialidadeLabel,
  });

  factory MedicoDisponivel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    
    return MedicoDisponivel(
      // ID do usuário (médico)
      userId: user['id'] ?? 0, 
      // Nome do médico (vindo do 'user')
      nomeCompleto: user['full_name'] ?? 'Nome não encontrado',
      // Chave da especialidade (vinda do 'medico')
      especialidadeKey: json['especialidade'] ?? '', 
      // Label da especialidade (que adicionamos no serializer)
      especialidadeLabel: json['especialidade_label'] ?? '', 
    );
  }
}