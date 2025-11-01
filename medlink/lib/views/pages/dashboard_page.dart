import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../services/api_service.dart';
import '../../models/dashboard_stats_model.dart';
import 'package:medlink/models/appointment_model.dart';
import 'package:medlink/models/patient_model.dart';
import 'package:medlink/models/doctor_model.dart';
import '../../models/patient_model.dart';
import '../../models/doctor_model.dart';

class SecretaryDashboard extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onNavigateToNewPatient;

  const SecretaryDashboard({
    Key? key,
    this.onLogout,
    this.onNavigateToNewPatient,
  }) : super(key: key);

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  // Estados da Tela
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();

  List<Appointment> _allAppointments = []; // Guarda a lista original da API
  List<Appointment> _filteredAppointments = []; // Lista exibida na tela
  List<Patient> _patients = [];
  List<Doctor> _doctors = [];
  DashboardStats? _stats;
  bool _isLoading = true;
  String _secretaryName = 'Secretária'; // Nome padrão
  String _searchTerm = '';
  Appointment? _selectedAppointment;
  String _cancelReason = '';
  int? _userClinicId;
  int? clinicaId;
  String _clinicName = 'Sua Clínica'; // Nome padrão da clínica

  // Constantes de Cor
  static const Color primaryColor = Color(0xFF0891B2);
  static const Color secondaryColor = Color(0xFF67E8F9);
  static const Color accentColor = Color(0xFFE0F2FE);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
        _filterAppointments();
      });
    });
    _loadClinicaId();
  }

  // Carrega o ID da clínica a partir do token JWT e atualiza o estado.
  Future<void> _loadClinicaId() async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) return;

      final Map<String, dynamic> decoded = JwtDecoder.decode(accessToken);
      if (!mounted) return;

      setState(() {
        // Alguns tokens podem usar 'clinica_id' ou 'clinicaId' dependendo do backend.
        _userClinicId = decoded['clinica_id'] ?? decoded['clinicaId'];
        clinicaId = _userClinicId;
      });
    } catch (_) {
      // Falha ao obter/decodificar token: não bloqueia a UI, apenas ignora.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Em _SecretaryDashboardState
  Map<String, int> get _summaryStats {
    return {
      'today': _allAppointments
          .where((a) => a.dateTime.day == DateTime.now().day)
          .length,
      'confirmed': _allAppointments
          .where((a) => a.status == 'confirmed')
          .length,
      'pending': _allAppointments.where((a) => a.status == 'pending').length,
      'totalMonth': _allAppointments
          .where(
            (a) =>
                a.dateTime.month == DateTime.now().month &&
                a.dateTime.year == DateTime.now().year,
          )
          .length,
    };
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) {
        throw Exception('Token não encontrado. Faça o login novamente.');
      }

      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);

      // Debug: imprima o token decodificado para verificar os campos
      print("Token decodificado: $decodedToken");

      // Tenta obter o nome da clínica de várias maneiras possíveis
      String? clinicName =
          decodedToken['clinic_name'] ??
          decodedToken['clinica_nome'] ??
          decodedToken['nome_clinica'];

      // Busca os dados da API em paralelo (sem bloquear a busca do nome da clínica)
      final resultsFuture = Future.wait([
        _apiService.getDashboardStats(accessToken),
        _apiService.getAppointments(accessToken),
        _apiService.getPatients(accessToken),
        _apiService.getDoctors(accessToken),
      ]);

      // Se tivermos clinic_id, tenta buscar o nome real da clínica pela API
      String? clinicNameFromApi;
      if (_userClinicId != null) {
        try {
          clinicNameFromApi = await _apiService.getClinicName(
            _userClinicId!,
            accessToken,
          );
        } catch (_) {
          clinicNameFromApi = null;
        }
      }

      final results = await resultsFuture;

      if (!mounted) return;

      // Debug: imprima os médicos carregados
      final doctors = results[3] as List<Doctor>;
      print('=== MÉDICOS CARREGADOS ===');
      print('Total: ${doctors.length}');
      for (var doc in doctors) {
        print('- ${doc.fullName} (ID: ${doc.id})');
      }
      print('========================');

      setState(() {
        _secretaryName = decodedToken['full_name'] ?? 'Secretária';
        _userClinicId = decodedToken['clinica_id'] != null
            ? int.tryParse(decodedToken['clinica_id'].toString())
            : null;
        _stats = results[0] as DashboardStats;
        _allAppointments = results[1] as List<Appointment>;
        _filteredAppointments = _allAppointments;
        _patients = results[2] as List<Patient>;
        _doctors = doctors;
        _clinicName = clinicName ?? 'Clínica não associada';
      });
    } catch (e) {
      print('ERRO ao carregar dados: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterAppointments() {
    if (_searchTerm.isEmpty) {
      _filteredAppointments = _allAppointments;
    } else {
      _filteredAppointments = _allAppointments.where((appointment) {
        final searchTermLower = _searchTerm.toLowerCase();
        final patientNameLower = appointment.patientName.toLowerCase();
        final doctorNameLower = appointment.doctorName.toLowerCase();
        return patientNameLower.contains(searchTermLower) ||
            doctorNameLower.contains(searchTermLower);
      }).toList();
    }
    setState(() {});
  }

  // ... (Suas funções _confirmAppointment, _cancelAppointment, _editAppointment, etc., viriam aqui)
  // Em _SecretaryDashboardState

  // --- FUNÇÕES DE AÇÃO DOS BOTÕES ---

  /// Confirma uma consulta pendente.
  Future<void> _confirmAppointment(int appointmentId) async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) throw Exception('Token não encontrado');

      final response = await _apiService.confirmAppointment(
        appointmentId,
        accessToken,
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consulta confirmada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInitialData(); // Atualiza a lista
      } else {
        throw Exception('Falha ao confirmar consulta: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Abre o dialog para cancelar uma consulta.
  void _showCancelDialog(Appointment appointment) {
    _selectedAppointment = appointment;
    _cancelReason = '';
    showDialog(context: context, builder: (context) => _buildCancelDialog());
  }

  /// Cancela a consulta selecionada.
  Future<void> _cancelAppointment() async {
    if (_selectedAppointment == null) return;
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) throw Exception('Token não encontrado');

      final response = await _apiService.cancelAppointment(
        _selectedAppointment!.id,
        _cancelReason,
        accessToken,
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.pop(context); // Fecha o dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consulta cancelada com sucesso!'),
            backgroundColor: Colors.blue,
          ),
        );
        _loadInitialData();
      } else {
        throw Exception('Falha ao cancelar consulta: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Abre o modal para editar (remarcar) uma consulta.
  void _showEditAppointmentDialog(Appointment appointment) {
    DateTime? selectedDate = appointment.dateTime;
    TimeOfDay? selectedTime = TimeOfDay.fromDateTime(appointment.dateTime);
    bool isDialogLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Remarcar Consulta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Paciente: ${appointment.patientName}'),
                  Text('Médico: ${appointment.doctorName}'),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat('dd/MM/yyyy').format(selectedDate!),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate!,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null)
                              setDialogState(() => selectedDate = date);
                          },
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(selectedTime!.format(context)),
                          onPressed: () async {
                            final picked = await _openTimeSlotPicker(
                              date: selectedDate!,
                              medicoId: appointment.doctorId,
                              pacienteId: appointment.patientId,
                              medicoNome: appointment.doctorName,
                              pacienteNome: appointment.patientName,
                            );
                            if (picked != null) {
                              setDialogState(() => selectedTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          setDialogState(() => isDialogLoading = true);
                          try {
                            final accessToken = await _storage.read(
                              key: 'access_token',
                            );
                            if (accessToken == null)
                              throw Exception('Token não encontrado');

                            final newDateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );

                            final response = await _apiService
                                .updateAppointment(
                                  appointment.id,
                                  newDateTime,
                                  accessToken,
                                );

                            if (!mounted) return;
                            if (response.statusCode == 200) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Consulta remarcada com sucesso!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadInitialData(); // Atualiza a lista
                            } else {
                              throw Exception(
                                'Falha ao remarcar: ${response.body}',
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (mounted)
                              setDialogState(() => isDialogLoading = false);
                          }
                        },
                  child: isDialogLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar Alterações'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // ... (Elas devem chamar a API e, no final, chamar _loadInitialData() para atualizar a tela)

  String get _todayFormatted {
    final now = DateTime.now();
    return DateFormat('EEEE, d \'de\' MMMM \'de\' y', 'pt_BR').format(now);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.3),
              backgroundColor,
              secondaryColor.withOpacity(0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsCards(),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildTodaySchedule()),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildQuickActions()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.local_hospital, size: 32, color: primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'MedLink',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _clinicName,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Painel da Secretária',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // NOME REAL DA SECRETÁRIA
                Text(
                  'Bem-vinda, $_secretaryName',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Text(
                  'Secretária',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sair'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    if (_isLoading || _stats == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Hoje',
            _stats!.today,
            Icons.calendar_today,
            primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Confirmadas',
            _stats!.confirmed,
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Pendentes',
            _stats!.pending,
            Icons.access_time,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Mês',
            _stats!.totalMonth,
            Icons.local_hospital,
            primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySchedule() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_today, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Agenda de Hoje',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _todayFormatted,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                // BARRA DE PESQUISA
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar paciente ou médico...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAppointments.isEmpty
                  ? const Center(child: Text("Nenhum agendamento encontrado."))
                  : ListView.builder(
                      itemCount: _filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = _filteredAppointments[index];
                        return _buildAppointmentCard(appointment);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Em _SecretaryDashboardState, substitua apenas este método

  Widget _buildAppointmentCard(Appointment appointment) {
    // A lógica de decisão de cor e texto agora fica aqui
    String statusLabel;
    Color statusColor;

    switch (appointment.status) {
      case 'pending':
        statusLabel = 'Pendente';
        statusColor = Colors.orange;
        break;
      case 'confirmed':
        statusLabel = 'Confirmada';
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusLabel = 'Cancelada';
        statusColor = Colors.red;
        break;
      default:
        statusLabel = appointment.status;
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Row(
        children: [
          // ... (Sua coluna de Hora, Paciente, Médico - já estão corretas)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('HH:mm').format(appointment.dateTime),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paciente: ${appointment.patientName}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Médico: Dr(a) ${appointment.doctorName}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // Coluna de Ações e Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 👇 CORREÇÃO APLICADA AQUI 👇
                  // Agora verificamos por 'pending' (em inglês)
                  if (appointment.status.toLowerCase() == 'pendente')
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: () => _confirmAppointment(appointment.id),
                        icon: const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.green,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green[50],
                          side: BorderSide(color: Colors.green[200]!),
                        ),
                      ),
                    ),

                  // 👇 CORREÇÃO APLICADA AQUI 👇
                  // Verificação para o botão de cancelar
                  if (appointment.status.toLowerCase() != 'cancelled')
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: () => _showCancelDialog(appointment),
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          side: BorderSide(color: Colors.red[200]!),
                        ),
                      ),
                    ),

                  // Botão de Editar (sempre aparece)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      onPressed: () => _showEditAppointmentDialog(appointment),
                      icon: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.blue,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        side: BorderSide(color: Colors.blue[200]!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel, // Mostra o texto em português para o usuário
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    // Este widget continua o mesmo
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ações Rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              'Nova Consulta',
              Icons.add,
              primaryColor,
              _showNewAppointmentDialog,
              isPrimary: true,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Novo Paciente',
              Icons.person_add,
              Colors.grey[700]!,
              _showNewPatientDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isPrimary = false,
  }) {
    // Este widget continua o mesmo
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? color : Colors.white,
          foregroundColor: isPrimary ? Colors.white : color,
          side: isPrimary ? null : BorderSide(color: Colors.grey[300]!),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  // Em _SecretaryDashboardState

  void _showNewAppointmentDialog() {
    Patient? selectedPatient;
    Doctor? selectedDoctor;
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final valorController = TextEditingController();
    final typeController = TextEditingController();
    String? modoAtendimento; // 'Presencial' ou 'Online'
    bool isDialogLoading = false;

    bool _hasLocalSlotConflict(
      DateTime dt,
      int? pacienteId,
      int? medicoId,
      String? pacienteNome,
      String? medicoNome,
    ) {
      // Mantém compatível usando a função de conflito central
      return _hasLocalSlotConflictDt(
        dt,
        pacienteId: pacienteId,
        medicoId: medicoId,
        pacienteNome: pacienteNome,
        medicoNome: medicoNome,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final baseBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        );
        InputDecoration deco(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.grey[50],
          enabledBorder: baseBorder,
          focusedBorder: baseBorder.copyWith(
            borderSide: const BorderSide(color: primaryColor, width: 1.5),
          ),
        );

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              title: Row(
                children: const [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryColor,
                    child: Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Novo Agendamento',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // Paciente
                    DropdownButtonFormField<Patient>(
                      value: selectedPatient,
                      decoration: deco('Paciente', Icons.person),
                      items: _patients
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedPatient = v),
                    ),
                    const SizedBox(height: 12),
                    // Médico
                    DropdownButtonFormField<Doctor>(
                      value: selectedDoctor,
                      decoration: deco('Médico', Icons.medical_services),
                      items: _doctors
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('Dr(a) ${d.fullName}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedDoctor = v),
                    ),
                    const SizedBox(height: 12),
                    // Atendimento
                    DropdownButtonFormField<String>(
                      value: modoAtendimento,
                      decoration: deco('Atendimento', Icons.video_call),
                      items: const [
                        DropdownMenuItem(
                          value: 'Presencial',
                          child: Text('Presencial'),
                        ),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text('Online'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => modoAtendimento = v),
                    ),
                    const SizedBox(height: 12),
                    // Tipo de consulta
                    TextFormField(
                      controller: typeController,
                      decoration: deco(
                        'Tipo de Consulta (ex.: Primeira vez, Retorno)',
                        Icons.category,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Valor
                    TextFormField(
                      controller: valorController,
                      keyboardType: TextInputType.number,
                      decoration: deco('Valor', Icons.attach_money),
                    ),
                    const SizedBox(height: 16),
                    // Seção: Data e Hora
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              selectedDate == null
                                  ? 'Selecionar data'
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(selectedDate!),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: Colors.grey[800],
                            ),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null)
                                setDialogState(() => selectedDate = date);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              selectedTime == null
                                  ? 'Selecionar hora'
                                  : selectedTime!.format(context),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: Colors.grey[800],
                            ),
                            onPressed: () async {
                              if (selectedDate == null ||
                                  selectedDoctor == null ||
                                  selectedPatient == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Selecione Paciente, Médico e Data primeiro.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final picked = await _openTimeSlotPicker(
                                date: selectedDate!,
                                medicoId: selectedDoctor!.id,
                                pacienteId: selectedPatient!.id,
                                medicoNome: selectedDoctor!.fullName,
                                pacienteNome: selectedPatient!.fullName,
                              );
                              if (picked != null)
                                setDialogState(() => selectedTime = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (selectedDate != null && selectedTime != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Selecionado: ${DateFormat('dd/MM/yyyy').format(selectedDate!)} às ${selectedTime!.format(context)}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isDialogLoading
                            ? null
                            : () async {
                                if (selectedPatient == null ||
                                    selectedDoctor == null ||
                                    selectedDate == null ||
                                    selectedTime == null ||
                                    modoAtendimento == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Preencha todos os campos (inclua o tipo de atendimento)',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                if (_userClinicId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Erro: ID da clínica não encontrado. Faça o login novamente.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                final proposed = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                  selectedTime!.hour,
                                  selectedTime!.minute,
                                );
                                final hasConflict = _hasLocalSlotConflict(
                                  proposed,
                                  selectedPatient!.id,
                                  selectedDoctor!.id,
                                  selectedPatient!.fullName,
                                  selectedDoctor!.fullName,
                                );
                                if (hasConflict) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Conflito: há consulta a menos de 30 minutos para o médico ou paciente.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() => isDialogLoading = true);
                                try {
                                  final accessToken = await _storage.read(
                                    key: 'access_token',
                                  );
                                  if (accessToken == null)
                                    throw Exception('Token não encontrado');
                                  final appointmentDateTime = proposed;
                                  final newAppointment = Appointment(
                                    id: 0,
                                    dateTime: appointmentDateTime,
                                    status: 'PENDENTE',
                                    valor:
                                        double.tryParse(valorController.text) ??
                                        0.0,
                                    patientName: '',
                                    doctorName: '',
                                    type: typeController.text.isEmpty
                                        ? '(${modoAtendimento})'
                                        : '${typeController.text} (${modoAtendimento})',
                                    patientId: selectedPatient!.id,
                                    doctorId: selectedDoctor!.id,
                                    clinicId: _userClinicId,
                                  );
                                  final response = await _apiService
                                      .createAppointment(
                                        newAppointment,
                                        accessToken,
                                      );
                                  if (!mounted) return;
                                  if (response.statusCode == 201) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Agendamento criado com sucesso!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadInitialData();
                                  } else {
                                    throw Exception(
                                      'Falha ao criar agendamento: ${response.body}',
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  if (mounted)
                                    setDialogState(
                                      () => isDialogLoading = false,
                                    );
                                }
                              },
                        icon: isDialogLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        label: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNewPatientDialog() {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController();
    final cpfController = TextEditingController();
    final emailController = TextEditingController();
    final telefoneController = TextEditingController();
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final baseBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        );
        InputDecoration deco(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.grey[50],
          enabledBorder: baseBorder,
          focusedBorder: baseBorder.copyWith(
            borderSide: const BorderSide(color: primaryColor, width: 1.5),
          ),
        );

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              title: Row(
                children: const [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryColor,
                    child: Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Cadastrar Novo Paciente',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nomeController,
                        decoration: deco('Nome Completo', Icons.badge),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cpfController,
                        decoration: deco('CPF', Icons.credit_card),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: deco('E-mail', Icons.alternate_email),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: telefoneController,
                        decoration: deco('Telefone', Icons.phone),
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isDialogLoading
                            ? null
                            : () async {
                                if (!(formKey.currentState?.validate() ??
                                    false))
                                  return;
                                setDialogState(() => isDialogLoading = true);
                                try {
                                  final accessToken = await _storage.read(
                                    key: 'access_token',
                                  );
                                  if (accessToken == null)
                                    throw Exception('Token não encontrado');

                                  final partes = nomeController.text.split(' ');
                                  final firstName = partes.isNotEmpty
                                      ? partes.first
                                      : '';
                                  final lastName = partes.length > 1
                                      ? partes.sublist(1).join(' ')
                                      : '';

                                  final userData = {
                                    "first_name": firstName,
                                    "last_name": lastName,
                                    "cpf": cpfController.text,
                                    "email": emailController.text,
                                    "telefone": telefoneController.text,
                                    "user_type": "PACIENTE",
                                    "password": cpfController.text.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    ),
                                  };

                                  final response = await _apiService
                                      .createPatient(userData, accessToken);
                                  if (!mounted) return;
                                  if (response.statusCode == 201) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Paciente criado com sucesso!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadInitialData();
                                  } else {
                                    final error = jsonDecode(
                                      utf8.decode(response.bodyBytes),
                                    );
                                    throw Exception(
                                      'Falha ao criar paciente: $error',
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  if (mounted)
                                    setDialogState(
                                      () => isDialogLoading = false,
                                    );
                                }
                              },
                        icon: isDialogLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        label: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Em _SecretaryDashboardState

  // SUBSTITUA a função _editAppointment por esta
  // Em _SecretaryDashboardState

  void _editAppointment(Appointment appointment) {
    // Guarda os valores iniciais da data e hora da consulta
    DateTime selectedDate = appointment.dateTime;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(appointment.dateTime);
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Remarcar Consulta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paciente: ${appointment.patientName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Médico: ${appointment.doctorName}'),
                  const SizedBox(height: 24),
                  const Text('Selecione a nova data e hora:'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat('dd/MM/yyyy').format(selectedDate),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(selectedTime.format(context)),
                          onPressed: () async {
                            final picked = await _openTimeSlotPicker(
                              date: selectedDate,
                              medicoId: appointment.doctorId,
                              pacienteId: appointment.patientId,
                              medicoNome: appointment.doctorName,
                              pacienteNome: appointment.patientName,
                            );
                            if (picked != null) {
                              setDialogState(() => selectedTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          setDialogState(() => isDialogLoading = true);
                          try {
                            final accessToken = await _storage.read(
                              key: 'access_token',
                            );
                            if (accessToken == null)
                              throw Exception('Token não encontrado');

                            final newDateTime = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );

                            final response = await _apiService
                                .updateAppointment(
                                  appointment.id,
                                  newDateTime,
                                  accessToken,
                                );

                            if (!mounted) return;
                            if (response.statusCode == 200) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Consulta remarcada com sucesso!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadInitialData(); // Atualiza a lista
                            } else {
                              throw Exception(
                                'Falha ao remarcar: ${response.body}',
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (mounted)
                              setDialogState(() => isDialogLoading = false);
                          }
                        },
                  child: isDialogLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar Alterações'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //_buildCancelDialog
  Widget _buildCancelDialog() {
    bool isDialogLoading = false;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Cancelar Agendamento'),
          content: TextField(
            onChanged: (value) => _cancelReason = value,
            decoration: const InputDecoration(
              labelText: 'Motivo do Cancelamento',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            ElevatedButton(
              // In _buildCancelDialog

              // ...
              onPressed: isDialogLoading
                  ? null
                  : () async {
                      if (_cancelReason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Por favor, insira o motivo do cancelamento.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isDialogLoading = true);
                      // 👇 CORRECTION: Call the function with NO arguments 👇
                      await _cancelAppointment();
                      // The pop is handled inside _cancelAppointment on success/failure
                    },

              //...
              child: isDialogLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Cancelar Agendamento'),
            ),
          ],
        );
      },
    );
  }

  // --- GERA SLOTS DE 30 MIN (08:00–20:00), PULA ALMOÇO (12:00–13:00) ---
  List<DateTime> _generateTimeSlots(DateTime date) {
    final start = DateTime(date.year, date.month, date.day, 8, 0);
    final end = DateTime(date.year, date.month, date.day, 20, 0);
    final slots = <DateTime>[];
    var t = start;
    while (t.isBefore(end)) {
      // pula 12:00 e 12:30
      if (!(t.hour == 12 && (t.minute == 0 || t.minute == 30))) {
        slots.add(t);
      }
      t = t.add(const Duration(minutes: 30));
    }
    return slots;
  }

  // --- CONFLITO LOCAL: ±30min mesmo médico OU paciente ---
  bool _hasLocalSlotConflictDt(
    DateTime dt, {
    int? pacienteId,
    int? medicoId,
    String? pacienteNome,
    String? medicoNome,
  }) {
    for (final a in _allAppointments) {
      final diff = a.dateTime.difference(dt).inMinutes.abs();
      final sameDoctor =
          (medicoId != null && a.doctorId != null && a.doctorId == medicoId) ||
          (medicoNome != null &&
              medicoNome.isNotEmpty &&
              a.doctorName.toLowerCase() == medicoNome.toLowerCase());
      final samePatient =
          (pacienteId != null &&
              a.patientId != null &&
              a.patientId == pacienteId) ||
          (pacienteNome != null &&
              pacienteNome.isNotEmpty &&
              a.patientName.toLowerCase() == pacienteNome.toLowerCase());
      if (diff < 30 && (sameDoctor || samePatient)) return true;
    }
    return false;
  }

  // --- MODAL: seleciona horário em grade ---
  Future<TimeOfDay?> _openTimeSlotPicker({
    required DateTime date,
    required int? medicoId,
    required int? pacienteId,
    String? medicoNome,
    String? pacienteNome,
  }) async {
    final slots = _generateTimeSlots(date);
    return await showDialog<TimeOfDay>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Selecione um horário'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((dt) {
                  final label = DateFormat('HH:mm').format(dt);
                  final hasConflict = _hasLocalSlotConflictDt(
                    dt,
                    pacienteId: pacienteId,
                    medicoId: medicoId,
                    pacienteNome: pacienteNome,
                    medicoNome: medicoNome,
                  );
                  return SizedBox(
                    width: 96,
                    child: OutlinedButton(
                      onPressed: hasConflict
                          ? null
                          : () {
                              Navigator.pop(
                                ctx,
                                TimeOfDay(hour: dt.hour, minute: dt.minute),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        foregroundColor: hasConflict ? Colors.grey : null,
                      ),
                      child: Text(label),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}
