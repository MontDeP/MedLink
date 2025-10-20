// lib/models/appointment_model.dart

class Appointment {
  final int id;
  final DateTime dateTime;
  final String status;
  final String patientName;
  final String doctorName;
  final String type;

  // Campos opcionais para criação
  final int? patientId;
  final int? doctorId;
  final int? clinicId;
  final double? valor;

  Appointment({
    required this.id,
    required this.dateTime,
    required this.status,
    required this.patientName,
    required this.doctorName,
    required this.type,
    this.valor,
    this.patientId,
    this.doctorId,
    this.clinicId,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String? ?? '00:00').split(':');
    final now = DateTime.now();
    final parsedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(timeParts[0]) ?? 0,
      int.tryParse(timeParts[1]) ?? 0,
    );

    return Appointment(
      id: json['id'] ?? 0,
      dateTime: parsedDateTime,
      patientName: json['patient'] ?? 'Paciente não informado',
      doctorName: json['doctor'] ?? 'Médico não informado',
      type: json['type'] ?? 'Não especificado',
      status: json['status'] ?? 'desconhecido',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data_hora': dateTime.toIso8601String(),
      'status_atual': status,
      'valor': valor?.toString(),
      'paciente': patientId,
      'medico': doctorId,
      'clinica': clinicId,
    };
  }
}
