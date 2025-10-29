// lib/views/pages/home_page.dart
// (VERSÃO ATUALIZADA - Card do Pop-up voltou a ser cinza)

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:medlink/services/api_service.dart'; // Nosso serviço de API
import 'package:medlink/models/dashboard_data_model.dart'; // Nossos novos modelos

import 'nova_consulta_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  // Mantendo a classe pública para evitar bugs do VS Code
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Future<DashboardData> _dashboardDataFuture;
  final ApiService _apiService = ApiService();

  // --- NOSSAS NOVAS CORES (HARMONIZADAS) ---
  final Color todayColor = Colors.blue.shade100; // Cor do dia de Hoje
  final Color selectedColor = const Color(0xFF0066CC); // Cor do dia Selecionado
  final Color eventBgColor = Colors.green.shade100; // Fundo verde claro (para calendário)
  final Color eventTextColor = Colors.green.shade900; // Texto verde escuro (para calendário)

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _apiService.fetchDashboardData();
    _selectedDay = _focusedDay;
  }

  // --- FUNÇÃO PARA CONSTRUIR A LEGENDA ---
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
  // --- FIM DA LEGENDA ---

  // --- MÉTODO DO POP-UP (Card voltou a ser cinza) ---
  void _showConsultaModal(
      BuildContext context, DateTime dia, List<ProximaConsulta> consultasDoDia) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          elevation: 0,
          backgroundColor: Colors.white, // Fundo branco
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400), // Limita a largura
            child: Column( // Layout principal
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // --- 1. CABEÇALHO (Título + Botão X) ---
                Padding(
                  // Padding ajustado para alinhar o título e o botão
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Consultas - ${DateFormat('dd/MM/yyyy', 'pt_BR').format(dia)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: selectedColor, // Cor principal do app
                        ),
                      ),
                      // Botão 'X' agora DENTRO do card
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                
                // --- 2. DIVISOR ---
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(height: 1, color: Colors.black12),
                ),

                // --- 3. LISTA DE CONSULTAS ---
                Flexible(
                  child: Padding(
                    // Padding para a lista (e para a barra de rolagem)
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: consultasDoDia.length,
                      itemBuilder: (context, index) {
                        final consulta = consultasDoDia[index];
                        
                        // --- Card de Item de Consulta (Cor alterada) ---
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            // --- ✨ COR ALTERADA DE VOLTA PARA CINZA ✨ ---
                            color: Colors.grey.shade100, 
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              // --- ✨ COR DA BORDA ALTERADA DE VOLTA PARA CINZA ✨ ---
                              color: Colors.grey.shade300, 
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LINHA 1: "Dr. Nome" (Texto preto)
                              Text(
                                "Dr. ${consulta.medico}",
                                style: const TextStyle( // Cor removida para usar padrão (preto)
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // LINHA 2: "ESPECIALIDADE" (Texto preto com opacidade)
                              Text(
                                consulta.especialidade.toUpperCase(),
                                style: TextStyle( // Cor removida para usar padrão (preto)
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black.withOpacity(0.7), // Leve opacidade
                                ),
                              ),
                              // Divisor interno
                              const Divider(height: 20, thickness: 0.5),
                              // Detalhes (Texto preto)
                              Text(
                                'Horário: ${DateFormat('HH:mm', 'pt_BR').format(consulta.data)}',
                                style: const TextStyle(fontSize: 15, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Local: ${consulta.local}',
                                style: const TextStyle(fontSize: 15, color: Colors.black87),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // --- FIM DO MÉTODO DO POP-UP ---


  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: FutureBuilder<DashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erro ao carregar dados: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Nenhum dado encontrado.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final dashboardData = snapshot.data!;
          final proximaConsulta = dashboardData.proximaConsulta;

          // --- LÓGICA DO CALENDÁRIO ATUALIZADA ---
          // Agora temos a lista completa de objetos
          final List<ProximaConsulta> _todasConsultas =
              dashboardData.todasConsultas;

          // O _diasDeConsulta (para pintar) ainda é uma lista de DateTime
          final List<DateTime> _diasDeConsulta = _todasConsultas
              .map((consulta) => DateTime.utc(
                    consulta.data.year,
                    consulta.data.month,
                    consulta.data.day,
                  ))
              .toSet()
              .toList();

          List<dynamic> _getEventsForDay(DateTime day) {
            DateTime dayUtc = DateTime.utc(day.year, day.month, day.day);
            for (DateTime diaConsulta in _diasDeConsulta) {
              if (isSameDay(diaConsulta, dayUtc)) {
                return ['consulta'];
              }
            }
            return [];
          }
          // --- FIM DA LÓGICA ---

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FOTO E NOME
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundImage: AssetImage(
                                'assets/images/user_placeholder.png'),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Olá,',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              Text(
                                dashboardData.nomePaciente,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // CARD DA PRÓXIMA CONSULTA
                      if (proximaConsulta != null) ...[
                        const Text(
                          'Próxima Consulta',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: screenWidth - 40,
                          height: 140,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      proximaConsulta.medico,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      proximaConsulta.especialidade,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${DateFormat("dd/MM/yyyy", "pt_BR").format(proximaConsulta.data)} • ${DateFormat("HH:mm", "pt_BR").format(proximaConsulta.data)}',
                                      style: const TextStyle(
                                          color: Colors.black87, fontSize: 13),
                                    ),
                                    Text(
                                      proximaConsulta.local,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 70,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: selectedColor, // Cor azul escura
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Faltam',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      proximaConsulta.data
                                          .difference(DateTime.now())
                                          .inDays
                                          .toString(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'dias',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Nenhuma consulta agendada',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 30),

                      // --- CALENDÁRIO E LEGENDA (AGORA JUNTOS) ---
                      Container(
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
                              focusedDay: _focusedDay,
                              
                              // --- Lógica de seleção ATIVADA ---
                              selectedDayPredicate: (day) => false, 
                              onDaySelected: (selectedDay, focusedDay) {
                                DateTime diaClicadoUtc = DateTime.utc(
                                    selectedDay.year,
                                    selectedDay.month,
                                    selectedDay.day);
                                List<ProximaConsulta> consultasDoDia =
                                    _todasConsultas.where((consulta) {
                                  DateTime diaConsultaUtc = DateTime.utc(
                                      consulta.data.year,
                                      consulta.data.month,
                                      consulta.data.day);
                                  return isSameDay(
                                      diaConsultaUtc, diaClicadoUtc);
                                }).toList();

                                if (consultasDoDia.isNotEmpty) {
                                  _showConsultaModal(
                                      context, selectedDay, consultasDoDia);
                                }
                                setState(() {
                                  _focusedDay = focusedDay;
                                });
                              },
                              onPageChanged: (focusedDay) {
                                setState(() {
                                  _focusedDay = focusedDay;
                                });
                              },
                              // --- FIM DA MUDANÇA ---

                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                              ),
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  bool hasEvent =
                                      _getEventsForDay(day).isNotEmpty;
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
                                  bool hasEvent =
                                      _getEventsForDay(day).isNotEmpty;
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
                                      style: TextStyle(
                                          color: Colors.grey.shade400),
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
                                selectedTextStyle:
                                    const TextStyle(color: Colors.black),
                              ),
                            ),

                            // Legenda movida para dentro do Card
                            const SizedBox(height: 16),
                            _buildLegend(), // Legenda já está atualizada
                            const SizedBox(height: 16), // Espaçamento inferior
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 100), // Espaço para o botão flutuante
                    ],
                  ),
                ),
              ),

              // BOTÃO FLUTUANTE DE ADICIONAR
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NovaConsultaPage(),
                      ),
                    );
                  },
                  backgroundColor: const Color(0xFF317714),
                  child: const Icon(Icons.add, size: 30),
                ),
              ),
            ],
          );
        },
      ),
      backgroundColor: const Color(0xFF5BBCDC),
    );
  }

  // --- WIDGET HELPER PARA CONSTRUIR AS CÉLULAS DO DIA ---
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
          // Adiciona borda se ela for definida (para estilos híbridos)
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