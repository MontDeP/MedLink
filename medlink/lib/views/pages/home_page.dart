// lib/views/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // Dados fictícios da próxima consulta — tipado corretamente
    final Map<String, Object> proximaConsulta = {
      'medico': 'Dra. Ana Oliveira',
      'especialidade': 'Cardiologista',
      'data': DateTime.now().add(const Duration(days: 3)),
      'local': 'Clínica Coração Saudável'
    };

    // Extrai e converte os valores com tipos seguros
    final String medico = proximaConsulta['medico'] as String;
    final String especialidade = proximaConsulta['especialidade'] as String;
    final DateTime dataConsulta = proximaConsulta['data'] as DateTime;
    final String local = proximaConsulta['local'] as String;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Stack(
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
                        backgroundImage: AssetImage('assets/images/user_placeholder.png'),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Olá,',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          Text(
                            'Nome do Paciente',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // TÍTULO PRÓXIMA CONSULTA
                  const Text(
                    'Próxima Consulta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 10),

                  // CARD DA PRÓXIMA CONSULTA
                  Container(
                    width: screenWidth - 40,
                    height: 140,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Coluna com informações da consulta (começando da margem esquerda)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                medico,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                especialidade,
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${DateFormat("dd/MM/yyyy").format(dataConsulta)} • ${DateFormat("HH:mm").format(dataConsulta)}',
                                style: const TextStyle(color: Colors.black87, fontSize: 13),
                              ),
                              Text(
                                local,
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                        // Quadrado com tempo restante até a consulta
                        Container(
                          width: 70,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0066CC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Faltam',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '3',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'dias',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // CALENDÁRIO FUNCIONAL
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
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

                  const SizedBox(height: 100),
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
                // abrir tela de novo agendamento
              },
              backgroundColor: const Color(0xFF317714),
              child: const Icon(Icons.add, size: 30),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF5BBCDC),
    );
  }
}