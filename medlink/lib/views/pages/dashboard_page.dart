import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../models/appointment_model.dart';
import '../../models/consulta_dashboard_model.dart';
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

      // Decodifica o token para pegar o nome do usuário
      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);

      // Busca os dados da API em paralelo
      final results = await Future.wait([
        _apiService.getDashboardStats(accessToken),
        _apiService.getAppointments(accessToken),
        _apiService.getPatients(accessToken),
        _apiService.getDoctors(accessToken),
      ]);

      if (!mounted) return;
      setState(() {
        _secretaryName = decodedToken['full_name'] ?? 'Secretária';
        _stats = results[0] as DashboardStats;
        _allAppointments = results[1] as List<Appointment>;
        _filteredAppointments = _allAppointments;
        _patients = results[2] as List<Patient>;
        _doctors = results[3] as List<Doctor>;
      });
    } catch (e) {
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
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime!,
                            );
                            if (time != null)
                              setDialogState(() => selectedTime = time);
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
                              _loadInitialData();
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
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Salvar'),
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
        const Row(
          children: [
            Icon(Icons.local_hospital, size: 32, color: primaryColor),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MedLink',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
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
                  'Médico: ${appointment.doctorName}',
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
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Novo Agendamento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Patient>(
                      hint: const Text('Selecione o Paciente'),
                      value: selectedPatient,
                      items: _patients.map((patient) {
                        return DropdownMenuItem(
                          value: patient,
                          child: Text(
                            patient.fullName,
                          ), // <-- Corrigido para fullName
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedPatient = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Doctor>(
                      hint: const Text('Selecione o Médico'),
                      value: selectedDoctor,
                      items: _doctors
                          .map(
                            (doctor) => DropdownMenuItem(
                              value: doctor,
                              child: Text(doctor.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedDoctor = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Consulta',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: valorController,
                      decoration: const InputDecoration(labelText: 'Valor'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              selectedDate == null
                                  ? 'Data'
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(selectedDate!),
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
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              selectedTime == null
                                  ? 'Hora'
                                  : selectedTime!.format(context),
                            ),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null)
                                setDialogState(() => selectedTime = time);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                          if (selectedPatient == null ||
                              selectedDoctor == null ||
                              selectedDate == null ||
                              selectedTime == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Preencha todos os campos'),
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

                            final appointmentDateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );
                            final newAppointment = Appointment(
                              id: 0, // O ID é gerado pelo backend
                              dateTime: appointmentDateTime,
                              status: 'PENDENTE',
                              valor:
                                  double.tryParse(valorController.text) ?? 0.0,
                              patientName: '',
                              doctorName: '',
                              type: typeController.text,
                              patientId: selectedPatient!.id,
                              doctorId: selectedDoctor!.id,
                              clinicId: 4, // TODO: Pegar o ID da clínica logada
                            );

                            final response = await _apiService
                                .createAppointment(newAppointment, accessToken);

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
                              _fetchAppointments(); // Atualiza a lista
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
                              setDialogState(() => isDialogLoading = false);
                          }
                        },
                  child: isDialogLoading
                      ? const CircularProgressIndicator()
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // As funções de confirmar e cancelar (_confirmAppointment, _cancelAppointment, etc.) continuam as mesmas

  // Em _SecretaryDashboardState

  Future<void> _fetchAppointments() async {
    // Renomeado para refletir que busca tudo
    setState(() => _isLoading = true);
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) throw Exception('Token não encontrado');

      // Busca todos os dados necessários em paralelo
      final results = await Future.wait([
        _apiService.getAppointments(accessToken),
        _apiService.getPatients(accessToken),
        _apiService.getDoctors(accessToken),
      ]);

      if (!mounted) return;
      setState(() {
        _allAppointments = results[0] as List<Appointment>;
        _filterAppointments(); // Aplica o filtro após atualizar a lista completa
        _patients = results[1] as List<Patient>;
        _doctors = results[2] as List<Doctor>;
      });
    } catch (e) {
      // ... (seu tratamento de erro)
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // Em _SecretaryDashboardState

  Future<void> _logout() async {
    // 1. Apaga todos os tokens salvos no armazenamento seguro.
    // É uma boa prática limpar tudo para garantir que nenhum dado antigo permaneça.
    await _storage.deleteAll();

    // 2. Navega para a tela de login ('/') e remove todas as telas anteriores da pilha.
    // Isso impede que o usuário aperte "voltar" e retorne ao dashboard.
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
  // Em _SecretaryDashboardState

  void _navigateToNewPatient() {
    // Navega para a nova tela, passando o ID do usuário como argumento
    Navigator.pushNamed(context, '/new-patient').then((_) {
      // Esta função será chamada quando você VOLTAR da tela de cadastro.
      // Recarregamos os dados para garantir que as listas de pacientes e
      // agendamentos estejam atualizadas.
      print("Voltando da tela de cadastro de paciente, atualizando dados...");
      _loadInitialData();
    });
  }
  // Em _SecretaryDashboardState

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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cadastrar Novo Paciente'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: cpfController,
                        decoration: const InputDecoration(labelText: 'CPF'),
                        validator: (v) =>
                            v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: telefoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
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
                          if (!(formKey.currentState?.validate() ?? false))
                            return;

                          setDialogState(() => isDialogLoading = true);

                          try {
                            final accessToken = await _storage.read(
                              key: 'access_token',
                            );
                            if (accessToken == null)
                              throw Exception('Token não encontrado');

                            // Separa nome e sobrenome para enviar para a API de admin
                            final nomeCompleto = nomeController.text.split(' ');
                            final firstName = nomeCompleto.isNotEmpty
                                ? nomeCompleto.first
                                : '';
                            final lastName = nomeCompleto.length > 1
                                ? nomeCompleto.sublist(1).join(' ')
                                : '';

                            final userData = {
                              "first_name": firstName,
                              "last_name": lastName,
                              "cpf": cpfController.text,
                              "email": emailController.text,
                              "telefone": telefoneController.text,
                              "user_type": "PACIENTE",
                              // A senha pode ser gerada pelo backend ou podemos enviar uma padrão
                              "password": cpfController.text.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              ),
                            };

                            final response = await _apiService.createPatient(
                              userData,
                              accessToken,
                            );

                            if (!mounted) return;
                            if (response.statusCode == 201) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Paciente criado com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadInitialData(); // Atualiza a lista de pacientes
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
                              setDialogState(() => isDialogLoading = false);
                          }
                        },
                  child: isDialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // Em _SecretaryDashboardState

  // Em _SecretaryDashboardState

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
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
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

  // E não se esqueça de ajustar a chamada no _buildAppointmentCard
  // para passar o objeto `appointment` inteiro:
  // onPressed: () => _editAppointment(appointment),

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
}
