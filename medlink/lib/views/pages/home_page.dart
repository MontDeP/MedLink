// lib/views/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:medlink/services/api_service.dart'; // Nosso serviço de API
import 'package:medlink/models/dashboard_data_model.dart'; // Nossos novos modelos


import 'nova_consulta_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Future<DashboardData> _dashboardDataFuture;
  final ApiService _apiService = ApiService(); // Instancia o serviço

  @override
  void initState() {
    super.initState();
    // Inicia a chamada de API assim que a página é construída
    _dashboardDataFuture = _apiService.fetchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
      ),
      // --- FUTURE BUILDER ADICIONADO ---
      body: FutureBuilder<DashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          // --- ESTADO DE CARREGAMENTO ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          
          // --- ESTADO DE ERRO ---
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

          // --- ESTADO DE SUCESSO ---
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Nenhum dado encontrado.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // DADOS CARREGADOS COM SUCESSO!
          final dashboardData = snapshot.data!;
          final proximaConsulta = dashboardData.proximaConsulta;

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FOTO E NOME (AGORA DINÂMICO)
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundImage: AssetImage('assets/images/user_placeholder.png'), // Você pode trocar isso por uma foto real se a API enviar
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Olá,',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              Text(
                                dashboardData.nomePaciente, // <<< DADO DINÂMICO
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 30),

                      // --- LÓGICA DO CARD DE CONSULTA ---
                      // Verifica se existe uma próxima consulta
                      if (proximaConsulta != null) ...[
                        const Text(
                          'Próxima Consulta',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        
                        // CARD DA PRÓXIMA CONSULTA (AGORA DINÂMICO)
                        Container(
                          width: screenWidth - 40,
                          height: 140,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                      proximaConsulta.medico, // <<< DADO DINÂMICO
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      proximaConsulta.especialidade, // <<< DADO DINÂMICO
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      // Formata a data vinda da API
                                      '${DateFormat("dd/MM/yyyy", "pt_BR").format(proximaConsulta.data)} • ${DateFormat("HH:mm", "pt_BR").format(proximaConsulta.data)}', // <<< DADO DINÂMICO
                                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                                    ),
                                    Text(
                                      proximaConsulta.local, // <<< DADO DINÂMICO
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Calcula os dias restantes dinamicamente
                              Container(
                                width: 70,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0066CC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Faltam',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      // Calcula a diferença de dias
                                      proximaConsulta.data.difference(DateTime.now()).inDays.toString(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'dias',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Se não houver consulta, mostra esta mensagem
                        const Text(
                          'Nenhuma consulta agendada',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                      // --- FIM DA LÓGICA DO CARD ---

                      const SizedBox(height: 30),

                      // CALENDÁRIO (sem alteração)
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
                        child: TableCalendar(
                          locale: 'pt_BR',
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: Color(0xFF0066CC),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 100), // Espaço para o botão flutuante
                    ],
                  ),
                ),
              ),

              // BOTÃO FLUTUANTE DE ADICIONAR (sem alteração)
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
}