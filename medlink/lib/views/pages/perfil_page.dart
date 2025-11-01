// lib/views/pages/perfil_page.dart (VERSÃO COM CORREÇÃO DE ESTADO)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medlink/controllers/profile_controller.dart';
import 'package:medlink/views/widgets/perfil/profile_body.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  // --- MUDANÇA 1: O Controller é criado aqui ---
  late final ProfileController _profileController;

  late FocusNode _cepFocusNode;
  late FocusNode _dataNascimentoFocusNode;

  @override
  void initState() {
    super.initState();

    // --- MUDANÇA 2: O Controller é inicializado UMA VEZ ---
    _profileController = ProfileController();

    _cepFocusNode = FocusNode();
    _cepFocusNode.addListener(_onCepFocusChange);

    _dataNascimentoFocusNode = FocusNode();
    _dataNascimentoFocusNode.addListener(_onDataNascimentoFocusChange);
    
    // Não precisamos mais do WidgetsBinding.instance.addPostFrameCallback
    // porque o controller é inicializado aqui e o fetchProfile é chamado no construtor dele.
  }

  @override
  void dispose() {
    _cepFocusNode.removeListener(_onCepFocusChange);
    _cepFocusNode.dispose();

    _dataNascimentoFocusNode.removeListener(_onDataNascimentoFocusChange);
    _dataNascimentoFocusNode.dispose();

    // --- MUDANÇA 3: Faz o dispose do controller ---
    _profileController.dispose();

    super.dispose();
  }

  // Função chamada quando o foco do campo CEP muda
  void _onCepFocusChange() {
    if (!mounted) return;
    // Usa a instância local do controller
    if (!_cepFocusNode.hasFocus && _profileController.isEditing) {
      final cepMask = _profileController.cepMaskFormatter;
      final cepValue = cepMask.unmaskText(_profileController.cepController.text);
      
      if (cepValue.length == 8) {
        _profileController.buscarCep();
      } else if (cepValue.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('CEP inválido. Deve conter 8 dígitos.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  // Função chamada quando o foco da Data de Nascimento muda
  void _onDataNascimentoFocusChange() {
    if (!mounted) return;
    // Usa a instância local do controller
    if (!_dataNascimentoFocusNode.hasFocus && _profileController.isEditing) {
      _profileController.updateAgeFromTextField();
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- MUDANÇA 4: Usamos ChangeNotifierProvider.value ---
    // Em vez de criar um novo, nós FORNECEMOS o controller que já existe.
    return ChangeNotifierProvider.value(
      value: _profileController,
      child: Consumer<ProfileController>(
        builder: (context, controller, child) {
          // O resto do seu build continua exatamente igual
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 195, 247, 250),
            appBar: AppBar(
              title: const Text('Meu Perfil'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (!controller.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TextButton(
                      onPressed: controller.isSaving
                          ? null
                          : () async {
                              if (controller.isEditing) {
                                bool success = await controller.saveProfile();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(success
                                            ? 'Perfil atualizado com sucesso!'
                                            : 'Erro ao salvar: ${controller.errorMessage ?? 'Tente novamente.'}'),
                                        backgroundColor:
                                            success ? Colors.green : Colors.red),
                                  );
                                }
                              } else {
                                controller.startEditing();
                              }
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: controller.isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              controller.isEditing ? 'SALVAR' : 'EDITAR',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
              ],
            ),
            body: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : controller.errorMessage != null &&
                        !controller.isCepLoading &&
                        !(controller.errorMessage
                                ?.toLowerCase()
                                .contains('cep') ??
                            false)
                    ? Center(
                        child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(controller.errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 16),
                            textAlign: TextAlign.center),
                      ))
                    : ProfileBody(
                        controller: controller, // Passa o controller (que agora persiste)
                        cepFocusNode: _cepFocusNode,
                        dataNascimentoFocusNode: _dataNascimentoFocusNode,
                      ),
          );
        },
      ),
    );
  }
}