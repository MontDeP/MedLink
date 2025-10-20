// lib/models/dashboard_stats_model.dart

class DashboardStats {
  final int today;
  final int confirmed;
  final int pending;
  final int totalMonth;

  DashboardStats({
    this.today = 0,
    this.confirmed = 0,
    this.pending = 0,
    this.totalMonth = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      today: json['today'] ?? 0,
      confirmed: json['confirmed'] ?? 0,
      pending: json['pending'] ?? 0,
      totalMonth: json['totalMonth'] ?? 0,
    );
  }
}
