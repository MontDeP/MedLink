// lib/views/pages/medico_agenda_page.dart (VERSÃO FINAL CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';
import '../widgets/medico_app_bar.dart';

class MedicoAgendaPage extends StatefulWidget {
  const MedicoAgendaPage({super.key});

  @override
  State<MedicoAgendaPage> createState() => _MedicoAgendaPageState();
}

class _MedicoAgendaPageState extends State<MedicoAgendaPage> {
  final ApiService _apiService = ApiService();

  Map<DateTime, List<dynamic>> _events = {};
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointmentsForMonth(_focusedDay.year, _focusedDay.month);
  }

  Future<void> _fetchAppointmentsForMonth(int year, int month) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final eventsData = await _apiService.getMedicoAgenda(year, month);
      
      final Map<DateTime, List<dynamic>> mappedEvents = {};
      eventsData.forEach((dateString, appointments) {
        final dateParts = dateString.split('-');
        final date = DateTime.utc(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        mappedEvents[date] = appointments;
      });

      setState(() {
        _events = mappedEvents;
      });

    } catch (e) {
      setState(() {
        _errorMessage = "Erro ao carregar agenda: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    DateTime dayUtc = DateTime.utc(day.year, day.month, day.day);
    return _events[dayUtc] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8), 
      appBar: const MedicoAppBar(activePage: "Agenda"),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : TableCalendar(
                  locale: 'pt_BR',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  rowHeight: 80, 

                  // CORREÇÃO: Adicionada a altura para a linha dos dias da semana
                  daysOfWeekHeight: 60,

                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  onPageChanged: (focusedDay) {
                    if (_focusedDay.month != focusedDay.month || _focusedDay.year != focusedDay.year) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                      _fetchAppointmentsForMonth(focusedDay.year, focusedDay.month);
                    }
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w500),
                    leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black54),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black54),
                  ),

                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    weekendStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
                  ),

                  calendarStyle: CalendarStyle(
                    tableBorder: TableBorder.all(color: Colors.grey[300]!, width: 1),
                    defaultTextStyle: const TextStyle(fontSize: 16),
                    weekendTextStyle: const TextStyle(fontSize: 16, color: Colors.redAccent),
                    outsideTextStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                    todayDecoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: MedicoAppBar.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),

                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          top: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[400],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${events.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}