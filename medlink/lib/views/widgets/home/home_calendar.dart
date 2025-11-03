// lib/views/widgets/home/home_calendar.dart (COM A MODIFICAÇÃO)
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:medlink/controllers/home_controller.dart';
import 'package:medlink/models/dashboard_data_model.dart';
import 'consulta_modal.dart'; // Importa o nosso novo modal

class HomeCalendar extends StatelessWidget {
  final HomeController controller;

  // --- NOSSAS CORES (Trazidas da home_page) ---
  final Color todayColor = Colors.blue.shade100;
  final Color eventBgColor = Colors.green.shade100;
  final Color eventTextColor = Colors.green.shade900;

  HomeCalendar({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TableCalendar(
            locale: 'pt_BR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: controller.focusedDay,
            
            // --- Lógica de seleção agora usa o Controller ---
            selectedDayPredicate: (day) => false, // Nenhum dia fica 'selecionado'
            
            // Ação de clique
            onDaySelected: (selectedDay, focusedDay) {
              List<ProximaConsulta> consultasDoDia = controller.getEventsForDay(selectedDay);
              if (consultasDoDia.isNotEmpty) {
                // Chama a função do modal
                showConsultaModal(context, selectedDay, consultasDoDia);
              }
              // Atualiza o foco (via controller)
              controller.onPageChanged(focusedDay);
            },
            
            // Ação de mudar de página
            onPageChanged: (focusedDay) {
              controller.onPageChanged(focusedDay);
            },

            // --- Eventos ---
            eventLoader: (day) {
              return controller.getEventsForDay(day);
            },
            
            // --- Estilos (como antes) ---
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarBuilders: CalendarBuilders(
              
              // 👇 --- MODIFICAÇÃO 1: REMOVER O PONTO PRETO --- 👇
              markerBuilder: (context, day, events) {
                // Retorna um container vazio para "esconder" o marcador padrão
                return Container();
              },
              // 👆 --- FIM DA MODIFICAÇÃO --- 👆

              defaultBuilder: (context, day, focusedDay) {
                bool hasEvent = controller.getEventsForDay(day).isNotEmpty;
                if (hasEvent) {
                  return _buildDayCell(
                    day: day.day,
                    bgColor: eventBgColor,
                    textColor: eventTextColor,
                  );
                }
                return null;
              },
              todayBuilder: (context, day, focusedDay) {
                bool hasEvent = controller.getEventsForDay(day).isNotEmpty;
                if (hasEvent) {
                  return _buildDayCell(
                    day: day.day,
                    bgColor: eventBgColor,
                    textColor: eventTextColor,
                    borderColor: todayColor,
                  );
                }
                return null;
              },
              selectedBuilder: (context, day, focusedDay) {
                return null;
              },
              outsideBuilder: (context, day, focusedDay) {
                return Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                );
              },
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: todayColor,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              selectedTextStyle: const TextStyle(color: Colors.black),
            ),
          ),

          // Legenda
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- HELPERS DE UI (Movidos para cá) ---

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(todayColor, "Hoje"),
        const SizedBox(width: 16),
        _buildLegendItem(eventBgColor, "Consulta"),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildDayCell({
    required int day,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
  }) {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 3)
              : null,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}