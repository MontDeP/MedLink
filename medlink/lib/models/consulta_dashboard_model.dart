// lib/models/consulta_dashboard_model.dart

class ConsultaDashboard {
  final int id;
  final String time;
  final String type;
  final String status;

  ConsultaDashboard({
    required this.id,
    required this.time,
    required this.type,
    required this.status,
  });

  factory ConsultaDashboard.fromJson(Map<String, dynamic> json) {
    return ConsultaDashboard(
      id: json['id'],
      time: json['time'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
