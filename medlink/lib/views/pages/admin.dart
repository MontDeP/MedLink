import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../services/api_service.dart'; // Garanta que este import está correto

// SUBSTITUA SEU ENUM POR ESTE
enum UserRole { secretaria, medico, admin, financeiro, paciente }

// SUBSTITUA SUA CLASSE AdminUser POR ESTA
class AdminUser {
  final String id;
  final String name;
  final String cpf;
  final String email;
  final UserRole role;
  final String? specialty;
  final String? crm;
  bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  // NOVOS CAMPOS
  final int? clinicaId; // FK para secretaria/paciente/admin
  final List<int>? clinicaIds; // M2M para médico

  AdminUser({
    required this.id,
    required this.name,
    required this.cpf,
    required this.email,
    required this.role,
    this.specialty,
    this.crm,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
    this.clinicaId,
    this.clinicaIds,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    String fullName =
        json['full_name'] ??
        '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim();
    if (fullName.isEmpty) fullName = 'Nome não informado';

    // Parse seguro de clinicaIds (lista)
    List<int>? parseClinicaIds(dynamic v) {
      if (v == null) return null;
      try {
        final list = (v as List)
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .toList();
        return list;
      } catch (_) {
        return null;
      }
    }

    return AdminUser(
      id: json['id']?.toString() ?? '0',
      name: fullName,
      cpf: json['cpf'] ?? '',
      email: json['email'] ?? '',
      // 👇 LÓGICA DE CONVERSÃO CORRIGIDA 👇
      role: UserRole.values.firstWhere(
        // Agora a comparação direta (minúsculo vs minúsculo) vai funcionar
        (e) => e.name == (json['user_type'] as String? ?? '').toLowerCase(),
        orElse: () => UserRole.paciente, // O padrão continua sendo 'paciente'
      ),
      specialty: json['specialty'],
      crm: json['crm'],
      isActive: json['is_active'] ?? false,
      createdAt: DateTime.tryParse(json['date_joined'] ?? '') ?? DateTime.now(),
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'])
          : null,
      // novos campos
      clinicaId: json['clinica_id'] != null
          ? int.tryParse(json['clinica_id'].toString())
          : null,
      clinicaIds: parseClinicaIds(json['clinica_ids']),
    );
  }
}

// --- FIM DOS MODELOS ---

class AdminDashboard extends StatefulWidget {
  final VoidCallback? onLogout;
  const AdminDashboard({Key? key, this.onLogout}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Variáveis de Estado para dados da API
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<AdminUser> _allUsers = [];
  bool _isLoading = true;
  String _adminName = "Admin";
  String _clinicName = "Sua Clínica"; // Novo estado
  int? _clinicaId; // Novo estado

  // Filtros
  String _searchTerm = '';
  UserRole? _filterRole;

  // Configurações (mantidas no estado da tela)
  final Map<String, bool> _generalSettings = {
    'autoScheduling': true,
    'emailNotifications': true,
    'autoBackup': true,
  };
  final Map<String, bool> _securitySettings = {
    'twoFactor': false,
    'auditLog': true,
    'autoSession': true,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const Color primaryColor = Color(0xFF0891B2);
  static const Color secondaryColor = Color(0xFF67E8F9);
  static const Color accentColor = Color(0xFFE0F2FE);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null)
        throw Exception('Token não encontrado. Faça o login novamente.');

      final decodedToken = JwtDecoder.decode(accessToken);
      final usersFromApi = await _apiService.getClinicUsers(accessToken);

      final adminClinicId = decodedToken['clinica_id'] != null
          ? int.tryParse(decodedToken['clinica_id'].toString())
          : null;

      debugPrint(
        '[AdminDashboard] token.clinica_id=$adminClinicId clinic_name=${decodedToken['clinic_name']}',
      );
      debugPrint('[AdminDashboard] usersFromApi=${usersFromApi.length}');

      List<AdminUser> filtered = usersFromApi;
      if (adminClinicId != null) {
        final hasHints = usersFromApi.any(
          (u) => (u.clinicaId != null) || ((u.clinicaIds?.isNotEmpty ?? false)),
        );
        debugPrint('[AdminDashboard] hasHints=$hasHints');

        if (hasHints) {
          filtered = usersFromApi.where((u) {
            if (u.role == UserRole.medico) {
              return (u.clinicaIds?.contains(adminClinicId) ?? false);
            } else {
              return (u.clinicaId != null) && (u.clinicaId == adminClinicId);
            }
          }).toList();
        }
      }
      debugPrint('[AdminDashboard] filtered=${filtered.length}');

      if (!mounted) return;
      setState(() {
        _adminName = decodedToken['full_name'] ?? 'Admin';
        _clinicName = decodedToken['clinic_name'] ?? 'Clínica não associada';
        _clinicaId = adminClinicId;
        _allUsers = filtered;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AdminUser> get _filteredUsers {
    return _allUsers.where((user) {
      final searchTermLower = _searchTerm.toLowerCase();

      // Adicionamos '?? ''' para garantir que não haverá erro se um campo for nulo
      final matchesSearch =
          _searchTerm.isEmpty ||
          (user.name ?? '').toLowerCase().contains(searchTermLower) ||
          (user.email ?? '').toLowerCase().contains(searchTermLower) ||
          (user.cpf ?? '').contains(searchTermLower);

      final matchesRole = _filterRole == null || user.role == _filterRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  Map<String, int> get _stats {
    return {
      'total': _allUsers.length,
      'active': _allUsers.where((u) => u.isActive).length,
      'doctors': _allUsers.where((u) => u.role == UserRole.medico).length,
      'secretaries': _allUsers
          .where((u) => u.role == UserRole.secretaria)
          .length,
      'patients': _allUsers.where((u) => u.role == UserRole.paciente).length,
    };
  }

  // Em _AdminDashboardState
  Map<String, dynamic> _getRoleConfig(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return {'label': 'Admin', 'color': Colors.purple};
      case UserRole.medico: // <-- Corrigido
        return {'label': 'Médico', 'color': Colors.blue};
      case UserRole.secretaria: // <-- Corrigido
        return {'label': 'Secretária', 'color': Colors.green};
      case UserRole.financeiro: // <-- Corrigido
        return {'label': 'Financeiro', 'color': Colors.orange};
      case UserRole.paciente: // <-- Corrigido
        return {'label': 'Paciente', 'color': Colors.grey};
    }
  }

  Future<void> _toggleUserStatus(String userId) async {
    final userIndex = _allUsers.indexWhere((u) => u.id == userId);
    if (userIndex == -1) return;
    final originalStatus = _allUsers[userIndex].isActive;
    final newStatus = !originalStatus;

    setState(() => _allUsers[userIndex].isActive = newStatus);

    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) throw Exception('Token não encontrado');
      await _apiService.updateUserStatus(userId, newStatus, accessToken);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status do usuário atualizado'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      setState(
        () => _allUsers[userIndex].isActive = originalStatus,
      ); // Reverte em caso de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(AdminUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('Confirmar Exclusão'),
          ],
        ),
        content: Text(
          'Tem certeza que deseja remover o usuário ${user.name}? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(user.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Confirmar Exclusão',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Em _AdminDashboardState

  // Em _AdminDashboardState

  Future<void> _deleteUser(String userId) async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) throw Exception('Token não encontrado');

      final response = await _apiService.deleteUser(userId, accessToken);

      // 204 No Content é a resposta padrão de sucesso para um DELETE
      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário removido com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        // Atualiza a lista de usuários na tela após a exclusão
        _loadInitialData();
      } else {
        // 👇 A LÓGICA PARA TRATAR O ERRO ACONTECE AQUI 👇

        String errorMessage = "Falha ao remover usuário."; // Mensagem padrão

        // Se o erro for 500, é muito provável que seja a nossa restrição de exclusão.
        // Então, mostramos a mensagem personalizada.
        if (response.statusCode == 500) {
          errorMessage =
              "Este usuário não pode ser excluído pois possui registros associados (como consultas). Considere inativá-lo.";
        } else if (response.body.isNotEmpty) {
          // Tenta pegar uma mensagem mais específica do backend, se houver
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['detail'] ?? errorMessage;
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      // Mostra a mensagem de erro (seja a genérica ou a nossa personalizada)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // O .replaceFirst remove o "Exception: " do início da mensagem
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nunca';
    return DateFormat('dd/MM/yyyy').format(date);
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsCards(),
                const SizedBox(height: 24),
                Expanded(child: _buildTabSection()),
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
            const Icon(Icons.monitor_heart, size: 32, color: primaryColor),
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
                Text(
                  'Painel Administrativo',
                  style: TextStyle(color: Colors.grey[600]),
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
                Text(
                  _adminName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Administrador',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
    return _isLoading
        ? const SizedBox(height: 60)
        : Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Usuários',
                  _stats['total']!,
                  Icons.people,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Ativos',
                  _stats['active']!,
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Médicos',
                  _stats['doctors']!,
                  Icons.local_hospital,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Secretárias',
                  _stats['secretaries']!,
                  Icons.admin_panel_settings,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Pacientes',
                  _stats['patients']!,
                  Icons.people,
                  Colors.grey,
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

  Widget _buildTabSection() {
    return Card(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: primaryColor,
            tabs: const [
              Tab(text: 'Usuários'),
              Tab(text: 'Configurações'),
              Tab(text: 'Relatórios'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(),
                _buildSettingsTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.people, color: primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Gerenciamento de Usuários',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              // Em _AdminDashboardState, dentro do método _buildUsersTab
              ElevatedButton.icon(
                onPressed: _showCreateUserDialog,
                icon: const Icon(
                  Icons.add,
                  size: 16,
                  color: Colors.white,
                ), // ícone branco
                label: const Text(
                  'Novo Usuário',
                  style: TextStyle(color: Colors.white), // texto branco
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, // cor de fundo do botão
                  foregroundColor: Colors
                      .white, // garante que o texto e o ícone fiquem brancos
                ),
              ),

              //...
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nome, email ou CPF...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchTerm = value),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<UserRole?>(
                  value: _filterRole,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos os tipos'),
                    ),
                    ...UserRole.values.map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(_getRoleConfig(role)['label']),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _filterRole = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    // Este widget permite a rolagem VERTICAL
                    child: SizedBox(
                      width: double.infinity, // Ocupa toda a largura possível
                      child: SingleChildScrollView(
                        // E este permite a rolagem HORIZONTAL
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing:
                              24, // Aumenta o espaçamento entre colunas
                          columns: const [
                            DataColumn(label: Text('Nome')),
                            DataColumn(label: Text('CPF')),
                            DataColumn(label: Text('E-mail')),
                            DataColumn(label: Text('Tipo')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Último Login')),
                            DataColumn(label: Text('Ações')),
                          ],
                          rows: _filteredUsers.map((user) {
                            final roleConfig = _getRoleConfig(user.role);
                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        user.name ?? 'Sem nome',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (user.specialty != null)
                                        Text(
                                          user.specialty!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(user.cpf ?? '')),
                                DataCell(Text(user.email ?? '')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (roleConfig['color'] as Color)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      roleConfig['label'],
                                      style: TextStyle(
                                        color: roleConfig['color'],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Switch(
                                    value: user.isActive,
                                    onChanged: (value) =>
                                        _toggleUserStatus(user.id),
                                    activeColor: primaryColor,
                                  ),
                                ),
                                DataCell(Text(_formatDate(user.lastLogin))),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () => _editUser(user.id),
                                        icon: const Icon(Icons.edit, size: 18),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _showDeleteConfirmation(user),
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red[600],
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configurações Gerais',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingSwitch(
              'Agendamento Automático',
              _generalSettings['autoScheduling']!,
              (val) => setState(() => _generalSettings['autoScheduling'] = val),
            ),
            _buildSettingSwitch(
              'Notificações por E-mail',
              _generalSettings['emailNotifications']!,
              (val) =>
                  setState(() => _generalSettings['emailNotifications'] = val),
            ),
            _buildSettingSwitch(
              'Backup Automático',
              _generalSettings['autoBackup']!,
              (val) => setState(() => _generalSettings['autoBackup'] = val),
            ),
            const Divider(height: 32),
            const Text(
              'Configurações de Segurança',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingSwitch(
              'Autenticação de Dois Fatores',
              _securitySettings['twoFactor']!,
              (val) => setState(() => _securitySettings['twoFactor'] = val),
            ),
            _buildSettingSwitch(
              'Registro de Auditoria',
              _securitySettings['auditLog']!,
              (val) => setState(() => _securitySettings['auditLog'] = val),
            ),
            _buildSettingSwitch(
              'Sessão Automática',
              _securitySettings['autoSession']!,
              (val) => setState(() => _securitySettings['autoSession'] = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: primaryColor,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildReportsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Relatórios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildReportCard('Relatório de Usuários', Icons.people, () {}),
                _buildReportCard(
                  'Relatório de Consultas',
                  Icons.event_note,
                  () {},
                ),
                _buildReportCard(
                  'Relatório Financeiro',
                  Icons.attach_money,
                  () {},
                ),
                _buildReportCard(
                  'Relatório de Atividades',
                  Icons.timeline,
                  () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Container(
          width: 200,
          height: 120,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: primaryColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Em _AdminDashboardState, substitua a função inteira

  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final cpfController = TextEditingController();
    final emailController = TextEditingController();
    final telefoneController = TextEditingController(); // NOVO
    final crmController = TextEditingController();
    final especialidadeController = TextEditingController();

    UserRole selectedRole = UserRole.secretaria;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Criar Novo Usuário'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Dados Pessoais',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'Primeiro Nome',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Obrigatório'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Último Nome',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Obrigatório'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cpfController,
                              decoration: const InputDecoration(
                                labelText: 'CPF',
                                hintText: 'Somente números',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Obrigatório'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: telefoneController,
                              decoration: const InputDecoration(
                                labelText: 'Telefone',
                                hintText: '(XX) 9XXXX-XXXX',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Obrigatório'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obrigatório'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Perfil',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<UserRole>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Usuário',
                          border: OutlineInputBorder(),
                        ),
                        items: UserRole.values.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(_getRoleConfig(role)['label']),
                          );
                        }).toList(),
                        onChanged: (role) {
                          if (role != null) {
                            setDialogState(() => selectedRole = role);
                          }
                        },
                      ),
                      // Campos exclusivos para Médico
                      if (selectedRole == UserRole.medico) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: crmController,
                                decoration: const InputDecoration(
                                  labelText: 'CRM',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    (selectedRole == UserRole.medico &&
                                        (v == null || v.trim().isEmpty))
                                    ? 'Obrigatório para Médico'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: especialidadeController,
                                decoration: const InputDecoration(
                                  labelText: 'Especialidade',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    (selectedRole == UserRole.medico &&
                                        (v == null || v.trim().isEmpty))
                                    ? 'Obrigatório para Médico'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Observação sobre a clínica
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _clinicaId != null
                              ? 'Usuário será associado à clínica deste administrador (ID: $_clinicaId).'
                              : 'Clínica do administrador não identificada. Faça login novamente se necessário.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
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
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() => isDialogLoading = true);
                          try {
                            final accessToken = await _storage.read(
                              key: 'access_token',
                            );
                            if (accessToken == null) {
                              throw Exception('Token não encontrado');
                            }

                            // Monta o payload (sem clinica_id: backend usa token)
                            final Map<String, dynamic> userData = {
                              "cpf": cpfController.text.trim(),
                              "email": emailController.text.trim(),
                              "first_name": firstNameController.text.trim(),
                              "last_name": lastNameController.text.trim(),
                              "user_type": selectedRole.name.toUpperCase(),
                              "telefone": telefoneController.text
                                  .trim(), // NOVO
                            };

                            if (selectedRole == UserRole.medico) {
                              userData['crm'] = crmController.text.trim();
                              userData['especialidade'] =
                                  especialidadeController.text
                                      .trim()
                                      .toUpperCase();
                            }

                            final response = await _apiService.createClinicUser(
                              userData,
                              accessToken,
                            );

                            if (!mounted) return;
                            if (response.statusCode == 201) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Usuário criado com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadInitialData();
                            } else {
                              final error = utf8
                                  .decode(response.bodyBytes)
                                  .toString();
                              throw Exception('Falha ao criar usuário: $error');
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
                            if (mounted) {
                              setDialogState(() => isDialogLoading = false);
                            }
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
  // Em _AdminDashboardState

  Future<void> _logout() async {
    // 1. Apaga todos os dados salvos no armazenamento seguro
    await _storage.deleteAll();

    // 2. Navega para a tela de login e remove todas as telas anteriores da pilha
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
  // Em _AdminDashboardState

  // SUBSTITUA a função _editUser (que você tinha no DataTable) por esta:
  void _editUser(String userId) {
    // Navega para a nova tela, passando o ID do usuário como argumento
    Navigator.pushNamed(context, '/admin/edit-user', arguments: userId).then((
      _,
    ) {
      // Esta função será chamada quando você VOLTAR da tela de edição.
      // Recarregamos os dados para garantir que a lista esteja atualizada.
      _loadInitialData();
    });
  }
}
