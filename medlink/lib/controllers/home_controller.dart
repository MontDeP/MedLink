// lib/controllers/home_controller.dart (NOVO ARQUIVO)
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:medlink/services/api_service.dart';
import 'package:medlink/models/dashboard_data_model.dart';

class HomeController extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // --- Estados da UI ---
  bool _isLoading = true;
  String? _errorMessage;
  DashboardData? _dashboardData;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardData? get dashboardData => _dashboardData;

  // --- Estados do Calendário ---
  DateTime _focusedDay = DateTime.now();
  final Map<DateTime, List<ProximaConsulta>> _eventsMap = {};

  DateTime get focusedDay => _focusedDay;
  
  // Lista de eventos para o dia (otimizado)
  List<ProximaConsulta> getEventsForDay(DateTime day) {
    DateTime dayUtc = DateTime.utc(day.year, day.month, day.day);
    return _eventsMap[dayUtc] ?? [];
  }

  // Construtor
  HomeController() {
    fetchDashboardData();
  }

  // --- Lógica de Negócio ---

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiService.fetchDashboardData();
      _dashboardData = data;
      _processEvents(data);
    } catch (e) {
      debugPrint("Erro ao buscar dashboard: $e");
      _errorMessage = "Erro ao carregar dados. Tente novamente.";
    }

    _isLoading = false;
    notifyListeners();
  }

  // Processa a lista de consultas e agrupa por dia
  void _processEvents(DashboardData data) {
    _eventsMap.clear();

    // vvvv INÍCIO DA CORREÇÃO vvvv
    // 1. Filtra a lista ANTES de processar
    final consultasValidas = data.todasConsultas.where((consulta) {
      // O seu modelo 'ProximaConsulta' já tem o campo 'status'
      return consulta.status.toLowerCase() != 'cancelada';
    });
    // ^^^^ FIM DA CORREÇÃO ^^^^


    // 2. Faz o loop apenas com as consultas válidas
    for (var consulta in consultasValidas) {
      DateTime diaConsultaUtc = DateTime.utc(
        consulta.data.year,
        consulta.data.month,
        consulta.data.day,
      );

      if (_eventsMap[diaConsultaUtc] == null) {
        _eventsMap[diaConsultaUtc] = [];
      }
      _eventsMap[diaConsultaUtc]!.add(consulta);
    }
  }

  // --- Ações do Calendário ---

  void onDaySelected(DateTime selectedDay, DateTime focusedDay, BuildContext context) {
    // Esta função agora só se preocupa em ABRIR o modal
    // A lógica de 'selected' não é mais necessária, pois o tap
    // apenas abre o pop-up.
    
    List<ProximaConsulta> consultasDoDia = getEventsForDay(selectedDay);

    if (consultasDoDia.isNotEmpty) {
      // (Vamos importar isso no widget do calendário)
      // showConsultaModal(context, selectedDay, consultasDoDia);
    }
    
    // Atualiza o foco
    _focusedDay = focusedDay;
    notifyListeners();
  }

  void onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    notifyListeners();
    // NOTA: Se a API `fetchDashboardData` precisasse do mês/ano,
    // nós a chamaríamos aqui novamente. Como ela traz tudo,
    // não precisamos recarregar.
  }
}