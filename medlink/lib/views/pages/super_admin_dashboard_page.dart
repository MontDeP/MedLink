import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart'; // add import

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _adminName = "Super Admin"; // Nome padrão
  List<Map<String, dynamic>> _clinics = [];
  bool _loadingClinics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadClinics();
    // opcional: carregar nome do admin do token
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      // mantém nome padrão se não houver 'full_name' no token
      setState(() => _adminName = _adminName);
    }
  }

  Future<void> _loadClinics() async {
    setState(() => _loadingClinics = true);
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('Token não encontrado');
      final data = await _apiService.getAllClinics(token);
      if (!mounted) return;
      setState(() {
        _clinics = data;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar clínicas: $e')));
    } finally {
      if (mounted) setState(() => _loadingClinics = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _storage.deleteAll();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Tema escuro para o Super Admin
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.shield_rounded),
            const SizedBox(width: 10),
            const Text('MedLink - Painel Geral'),
          ],
        ),
        actions: [
          Center(child: Text('Bem-vindo, $_adminName')),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
          const SizedBox(width: 20),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded), text: 'Gerenciar Clínicas'),
            Tab(
              icon: Icon(Icons.add_business_rounded),
              text: 'Cadastrar Nova Clínica',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildManageClinicsTab(), _buildCreateClinicTab()],
      ),
    );
  }

  /// Aba 1: Lista de Clínicas (dados reais)
  Widget _buildManageClinicsTab() {
    if (_loadingClinics) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_clinics.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma clínica encontrada.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _clinics.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.grey),
      itemBuilder: (_, i) {
        final c = _clinics[i];
        final name = (c['nome_fantasia'] ?? c['nome'] ?? 'Clínica').toString();
        final dynamicId = c['id'];
        final int id = (dynamicId is int)
            ? dynamicId
            : int.tryParse(dynamicId?.toString() ?? '') ?? -1;
        final cnpj = (c['cnpj'] ?? '').toString();
        return ListTile(
          leading: const Icon(Icons.business_rounded, color: Colors.white),
          title: Text(name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            'ID: $id${cnpj.isNotEmpty ? ' • CNPJ: $cnpj' : ''}',
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () =>
              _openAssignAdminSheet(id, name), // <-- mantém abrir modal
        );
      },
    );
  }

  void _openAssignAdminSheet(int clinicId, String clinicName) {
    final searchCtrl = TextEditingController();
    int? selectedAdminId;
    List<Map<String, dynamic>> admins = [];
    bool loading = true;
    bool saving = false;
    StateSetter? sheetSetState;

    Future<void> _loadAdmins({String? term}) async {
      try {
        final token = await _storage.read(key: 'access_token');
        if (token == null) throw Exception('Token não encontrado');
        final results = await _apiService.getAdmins(token, search: term);
        if (!mounted) return;
        sheetSetState?.call(() {
          admins = results;
          // preserva seleção se ainda existir na lista
          if (selectedAdminId != null &&
              !admins.any(
                (a) =>
                    (a['id']?.toString() ?? '') == selectedAdminId.toString(),
              )) {
            selectedAdminId = null;
          }
          loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar admins: $e')));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            sheetSetState = setStateModal;
            // Carrega admins na abertura
            if (loading && admins.isEmpty) {
              // ignora await — UI mostra progress
              _loadAdmins();
            }

            final inputDecoration = InputDecoration(
              border: const OutlineInputBorder(),
              labelStyle: TextStyle(color: Colors.grey[300]),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0891B2)),
              ),
            );
            const textStyle = TextStyle(color: Colors.white);

            Future<void> _save() async {
              if (selectedAdminId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selecione um Admin.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setStateModal(() => saving = true);
              try {
                final token = await _storage.read(key: 'access_token');
                if (token == null) throw Exception('Token não encontrado');
                final resp = await _apiService.assignClinicAdmin(clinicId, {
                  'admin_user_id': selectedAdminId,
                }, token);
                if (resp.statusCode == 200) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin atribuído com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Opcional: recarregar a lista de clínicas se quiser refletir "responsável" quando disponível
                  // await _loadClinics();
                } else {
                  final msg = utf8.decode(resp.bodyBytes);
                  throw Exception('Falha (${resp.statusCode}): $msg');
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setStateModal(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Editar Clínica • $clinicName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Busca
                  TextField(
                    controller: searchCtrl,
                    style: textStyle,
                    decoration: inputDecoration.copyWith(
                      labelText: 'Buscar Admin por nome/CPF/e-mail',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white70),
                        onPressed: () {
                          setStateModal(() => loading = true);
                          _loadAdmins(term: searchCtrl.text);
                        },
                      ),
                    ),
                    onSubmitted: (v) {
                      setStateModal(() => loading = true);
                      _loadAdmins(term: v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Lista de Admins
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    DropdownButtonFormField<int>(
                      value: selectedAdminId,
                      dropdownColor: Colors.grey[850],
                      style: textStyle,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Selecionar Administrador',
                      ),
                      items: admins.map((a) {
                        final id = a['id'] as int;
                        final nome =
                            (a['full_name'] ??
                                    '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}')
                                .toString()
                                .trim();
                        final cpf = (a['cpf'] ?? '').toString();
                        final email = (a['email'] ?? '').toString();
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            '$nome${cpf.isNotEmpty ? " • $cpf" : ""}${email.isNotEmpty ? " • $email" : ""}',
                            style: textStyle,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setStateModal(() => selectedAdminId = v),
                      validator: (v) =>
                          v == null ? 'Selecione um administrador' : null,
                    ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (loading || saving) ? null : _save,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: const Text(
                        'Salvar',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0891B2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Aba 2: Formulário para Criar Clínica + Admin da Clínica
  Widget _buildCreateClinicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: SizedBox(
          width: 600,
          child: CreateClinicForm(onCreated: _loadClinics), // recarrega lista
        ),
      ),
    );
  }
}

// Widget de formulário separado para gerenciar seu próprio estado
class CreateClinicForm extends StatefulWidget {
  const CreateClinicForm({Key? key, this.onCreated}) : super(key: key);
  final Future<void> Function()? onCreated;

  @override
  State<CreateClinicForm> createState() => _CreateClinicFormState();
}

class _CreateClinicFormState extends State<CreateClinicForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controladores (campos completos conforme modelo)
  final _clinicNameController = TextEditingController();
  final _clinicCnpjController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cepController = TextEditingController();
  final _telefoneController = TextEditingController();
  // (removidos do payload de criação: dados de admin)

  // Combos
  List<Map<String, dynamic>> _estados = [];
  List<Map<String, dynamic>> _cidades = [];
  List<Map<String, dynamic>> _tipos = [];
  int? _selectedEstadoId;
  int? _selectedCidadeId;
  int? _selectedTipoId;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) throw Exception('Token não encontrado');

      final api = ApiService();
      final results = await Future.wait([
        api.getEstados(token),
        api.getCidades(token),
        api.getTiposClinica(token),
      ]);

      if (!mounted) return;
      setState(() {
        _estados = results[0];
        _cidades = results[1];
        _tipos = results[2];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar referências: $e')),
      );
    }
  }

  @override
  void dispose() {
    _clinicNameController.dispose();
    _clinicCnpjController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _cepController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCidadeId == null || _selectedTipoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione Cidade e Tipo de Clínica.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'nome_fantasia': _clinicNameController.text.trim(),
        'cnpj': _clinicCnpjController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'logradouro': _logradouroController.text.trim(),
        'numero': _numeroController.text.trim(),
        'bairro': _bairroController.text.trim(),
        'cep': _cepController.text.trim(),
        'telefone': _telefoneController.text.trim(),
        'cidade': _selectedCidadeId,
        'tipo_clinica': _selectedTipoId,
      };

      final storage = const FlutterSecureStorage();
      final accessToken = await storage.read(key: 'access_token');
      if (accessToken == null) {
        throw Exception('Token não encontrado. Faça login novamente.');
      }

      final resp = await ApiService().createClinicOnly(data, accessToken);

      if (!mounted) return;
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clínica criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState?.reset();
        _clinicNameController.clear();
        _clinicCnpjController.clear();
        _logradouroController.clear();
        _numeroController.clear();
        _bairroController.clear();
        _cepController.clear();
        _telefoneController.clear();
        _selectedEstadoId = null;
        _selectedCidadeId = null;
        _selectedTipoId = null;

        if (widget.onCreated != null) await widget.onCreated!();
      } else {
        final msg = utf8.decode(resp.bodyBytes);
        throw Exception('Falha (${resp.statusCode}): $msg');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar clínica: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      border: const OutlineInputBorder(),
      labelStyle: TextStyle(color: Colors.grey[300]),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF0891B2)),
      ),
    );
    final textStyle = const TextStyle(color: Colors.white);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dados da Nova Clínica',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _clinicNameController,
            style: textStyle,
            decoration: inputDecoration.copyWith(labelText: 'Nome Fantasia'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _clinicCnpjController,
            style: textStyle,
            decoration: inputDecoration.copyWith(labelText: 'CNPJ'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _logradouroController,
            style: textStyle,
            decoration: inputDecoration.copyWith(labelText: 'Logradouro'),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _numeroController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Número'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _bairroController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Bairro'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cepController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'CEP'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _telefoneController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Telefone'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Estado (apenas informativo para ajudar a filtrar cidades localmente)
          DropdownButtonFormField<int>(
            value: _selectedEstadoId,
            decoration: inputDecoration.copyWith(labelText: 'Estado'),
            items: _estados.map((e) {
              return DropdownMenuItem<int>(
                value: e['id'] as int,
                child: Text(
                  (e['uf'] ?? e['nome'] ?? '').toString(),
                  style: textStyle,
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedEstadoId = val;
                // filtra cidades localmente por estado (se tiver campo estado no payload)
              });
            },
            dropdownColor: Colors.grey[850],
            style: textStyle,
          ),
          const SizedBox(height: 12),

          // Cidade (obrigatório)
          DropdownButtonFormField<int>(
            value: _selectedCidadeId,
            decoration: inputDecoration.copyWith(labelText: 'Cidade'),
            items: _cidades
                .where(
                  (c) =>
                      _selectedEstadoId == null ||
                      (c['estado'] == _selectedEstadoId),
                )
                .map(
                  (c) => DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text((c['nome'] ?? '').toString(), style: textStyle),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedCidadeId = val),
            validator: (v) => v == null ? 'Selecione a cidade' : null,
            dropdownColor: Colors.grey[850],
            style: textStyle,
          ),
          const SizedBox(height: 12),

          // Tipo de Clínica (obrigatório)
          DropdownButtonFormField<int>(
            value: _selectedTipoId,
            decoration: inputDecoration.copyWith(labelText: 'Tipo de Clínica'),
            items: _tipos
                .map(
                  (t) => DropdownMenuItem<int>(
                    value: t['id'] as int,
                    child: Text(
                      (t['descricao'] ?? '').toString(),
                      style: textStyle,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedTipoId = val),
            validator: (v) => v == null ? 'Selecione o tipo' : null,
            dropdownColor: Colors.grey[850],
            style: textStyle,
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSaving ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0891B2),
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : const Text(
                    'Criar Clínica',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }
}
