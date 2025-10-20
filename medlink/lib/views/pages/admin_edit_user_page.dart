import 'package:flutter/material.dart';
// lib/views/pages/admin_edit_user_page.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
// Import para ter acesso ao AdminUser e UserRole
import '../../views/pages/admin.dart';
import 'dart:convert';

class AdminEditUserPage extends StatefulWidget {
  final String userId;

  const AdminEditUserPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<AdminEditUserPage> createState() => _AdminEditUserPageState();
}

class _AdminEditUserPageState extends State<AdminEditUserPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Controladores para os campos do formulário
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _cpfController;

  AdminUser? _user;
  bool _isLoading = true;
  bool _isSaving = false;

  // --- NOVAS VARIÁVEIS DE ESTADO ---
  bool _isActive = true;
  UserRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _cpfController = TextEditingController();
    _fetchUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) throw Exception('Token não encontrado');

      final userFromApi = await _apiService.getSingleUser(
        widget.userId,
        accessToken,
      );

      setState(() {
        _user = userFromApi;
        _firstNameController.text = userFromApi.name.split(' ').first;
        _lastNameController.text = userFromApi.name.split(' ').last;
        _emailController.text = userFromApi.email;
        _cpfController.text = userFromApi.cpf;

        // --- PREENCHE AS NOVAS VARIÁVEIS DE ESTADO ---
        _isActive = userFromApi.isActive;
        _selectedRole = userFromApi.role;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar usuário: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) throw Exception('Token não encontrado');

      // --- MONTA O MAPA COM OS NOVOS DADOS ---
      final Map<String, dynamic> updatedData = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'cpf': _cpfController.text,
        'is_active': _isActive,
        'user_type': _selectedRole?.name.toUpperCase(),
      };

      final response = await _apiService.updateUser(
        widget.userId,
        updatedData,
        accessToken,
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Volta para a lista de usuários
      } else {
        throw Exception('Falha ao salvar: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLoading ? "Carregando..." : "Editar Usuário: ${_user?.name ?? ''}",
        ),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
          ? const Center(
              child: Text("Não foi possível carregar os dados do usuário."),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Primeiro Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Último Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cpfController,
                      decoration: const InputDecoration(
                        labelText: 'CPF',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- NOVOS CAMPOS ADICIONADOS AO FORMULÁRIO ---
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Usuário',
                        border: OutlineInputBorder(),
                      ),
                      items: UserRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(
                            role.name[0].toUpperCase() + role.name.substring(1),
                          ),
                        );
                      }).toList(),
                      onChanged: (role) {
                        setState(() {
                          _selectedRole = role;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Usuário Ativo'),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                      activeColor: const Color(0xFF0891B2),
                    ),

                    // --- FIM DOS NOVOS CAMPOS ---
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0891B2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Salvar Alterações',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
