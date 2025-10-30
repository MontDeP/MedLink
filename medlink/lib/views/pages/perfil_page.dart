// lib/views/pages/perfil_page.dart 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para input formatters
import 'package:intl/intl.dart';    // Para Locale e formatação (ainda útil)
import 'package:provider/provider.dart';
import 'package:medlink/controllers/profile_controller.dart'; 
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:io'; 
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

// --- Convertido para StatefulWidget ---
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

// --- Toda a lógica da UI agora fica dentro da classe State ---
class _PerfilPageState extends State<PerfilPage> {
  // FocusNode para detectar saída do campo CEP
  late FocusNode _cepFocusNode;

  // Máscaras de formatação
  final _cepMaskFormatter = MaskTextInputFormatter(
    mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});
  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cpfMaskFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _dateMaskFormatter = MaskTextInputFormatter(
    mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

  // Lista de tipos sanguíneos para o pop-up
  final List<String> _tiposSanguineos = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        // O ProfileController já deve chamar fetchProfile internamente
    });

    _cepFocusNode = FocusNode();
    _cepFocusNode.addListener(_onCepFocusChange);
  }

  @override
  void dispose() {
    _cepFocusNode.removeListener(_onCepFocusChange);
    _cepFocusNode.dispose();
    super.dispose();
  }

  // Função chamada quando o foco do campo CEP muda
  void _onCepFocusChange() {
    if (!mounted) return;
    final controller = Provider.of<ProfileController>(context, listen: false);
    if (!_cepFocusNode.hasFocus && controller.isEditing) {
      final cepMask = controller.cepMaskFormatter ?? _cepMaskFormatter;
      final cepValue = cepMask.unmaskText(controller.cepController.text);
      if (cepValue.length == 8) {
          controller.buscarCep();
      } else if (cepValue.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CEP inválido. Deve conter 8 dígitos.'), backgroundColor: Colors.orange),
          );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileController(),
      child: Consumer<ProfileController>(
        builder: (context, controller, child) {
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
                      onPressed: controller.isSaving ? null : () async {
                        if (controller.isEditing) {
                          bool success = await controller.saveProfile();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(success ? 'Perfil atualizado com sucesso!' : 'Erro ao salvar: ${controller.errorMessage ?? 'Tente novamente.'}'),
                                  backgroundColor: success ? Colors.green : Colors.red),
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            controller.isEditing ? 'SALVAR' : 'EDITAR',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                    ),
                  ),
              ],
            ),
            body: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : controller.errorMessage != null && !controller.isCepLoading && !(controller.errorMessage?.toLowerCase().contains('cep') ?? false)
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(controller.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                      ))
                    : _buildProfileBody(context, controller),
          );
        },
      ),
    );
  }


  // --- WIDGET DO CORPO DO PERFIL ---
  Widget _buildProfileBody(BuildContext context, ProfileController controller) {
    final bool isReadOnly = !controller.isEditing;
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      labelStyle: const TextStyle(color: Colors.black54),
      floatingLabelStyle: const TextStyle(color: Colors.blue),
      hintStyle: TextStyle(color: Colors.grey.shade400),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Parte Superior (Avatar, Nome) ---
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                  width: double.infinity, height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20),
                    )
                  ),
                ),
              Positioned(
                top: 30,
                child: Stack(
                  children: [
                    // 3. CIRCLEAVATAR MODIFICADO
                    CircleAvatar(
                      radius: 70,
                      backgroundImage: _getProfileImage(controller), // Usa o helper
                      backgroundColor: Colors.grey[300],
                    ),
                    if (controller.isEditing)
                      Positioned(
                        bottom: 0, right: 0,
                        child: CircleAvatar(
                          radius: 20, backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                            tooltip: 'Alterar foto',
                            // 4. ONPRESSED MODIFICADO
                            onPressed: () {
                                _showImageSourceActionSheet(context, controller);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
          Center(
            child: Text(
              controller.nomeCompletoController.text.isNotEmpty
                  ? controller.nomeCompletoController.text : "Nome do Usuário",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // --- Linha de Informações (Altura, Peso, Idade, Sangue) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoItem( // Altura
                context: context, title: 'Altura (cm)', icon: Icons.height,
                displayController: controller.alturaController,
                onTap: () => _showEditInfoDialog(
                  context: context, title: 'Altura (cm)', targetController: controller.alturaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              _infoItem( // Peso
                context: context, title: 'Peso (kg)', icon: Icons.monitor_weight,
                displayController: controller.pesoController,
                onTap: () => _showEditInfoDialog(
                  context: context, title: 'Peso (kg)', targetController: controller.pesoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}'))],
                ),
              ),
              _infoItem( // Idade
                context: context, title: 'Idade', icon: Icons.cake,
                displayController: controller.idadeController, onTap: null,
              ),
              // ==========================================================
              // MODIFICADO: onTap para Sangue chama o novo dialog
              _infoItem( // Sangue
                context: context, title: 'Sangue', icon: Icons.bloodtype,
                displayController: controller.sangueController,
                onTap: () => _showBloodTypeSelectionDialog(context, controller), // Chama a nova função
              ),
              // ==========================================================
            ],
          ),
          const SizedBox(height: 16),

          // --- Formulário ---
          _buildSectionTitle('Informações Pessoais'),
          _inputField('Nome Completo', controller.nomeCompletoController, inputDecoration, readOnly: isReadOnly),
          _inputField('CPF', controller.cpfController, inputDecoration, readOnly: true, labelColor: Colors.grey, inputFormatters: [_cpfMaskFormatter]),
          _inputField('Email', controller.emailController, inputDecoration, readOnly: true, labelColor: Colors.grey),
          _inputField(
            'Telefone', controller.telefoneController, inputDecoration, readOnly: isReadOnly,
            keyboardType: TextInputType.phone, inputFormatters: [_phoneMaskFormatter],
          ),
          _inputField( // Data Nascimento (TextField com máscara)
            'Data Nascimento', controller.dataNascimentoController, inputDecoration, readOnly: isReadOnly,
            labelColor: isReadOnly ? Colors.grey : null,
            keyboardType: TextInputType.datetime, inputFormatters: [_dateMaskFormatter],
            onTap: null, // Não abre mais calendário
          ),

          _buildSectionTitle('Endereço'),
          // --- CAMPO CEP com busca ---
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.cepController,
                    focusNode: _cepFocusNode, readOnly: isReadOnly,
                    keyboardType: TextInputType.number,
                    inputFormatters: [controller.cepMaskFormatter ?? _cepMaskFormatter],
                    decoration: inputDecoration.copyWith(
                      labelText: 'CEP', fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
                      labelStyle: TextStyle(color: isReadOnly ? Colors.grey.shade700 : Colors.black54),
                      hintText: '00000-000',
                    ),
                    style: TextStyle(color: isReadOnly ? Colors.grey.shade700 : Colors.black),
                  ),
                ),
                if (controller.isEditing)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                    child: controller.isCepLoading
                      ? const SizedBox( width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.search, color: Colors.blue),
                          onPressed: controller.buscarCep, tooltip: 'Buscar Endereço',
                        ),
                  ),
              ],
            ),
          ),
           if (controller.errorMessage != null && (controller.errorMessage?.toLowerCase().contains('cep') ?? false))
             Padding(
               padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
               child: Text(
                 controller.errorMessage!,
                 style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w500)
               ),
             ),
          // --- FIM DO CAMPO CEP ---

          _inputField('Bairro', controller.bairroController, inputDecoration, readOnly: isReadOnly),
          _inputField('Av/Rua', controller.avRuaController, inputDecoration, readOnly: isReadOnly),
          _inputField('Número', controller.numeroController, inputDecoration, readOnly: isReadOnly),

          _buildSectionTitle('Informações Adicionais'),
          TextFormField(
            controller: controller.infoAdicionaisController, readOnly: isReadOnly,
            maxLines: 5, minLines: 3,
            decoration: inputDecoration.copyWith(
              hintText: 'Alergias, condições pré-existentes, etc.',
              fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
              alignLabelWithHint: true, labelText: 'Notas Adicionais',
            ),
              style: TextStyle(color: isReadOnly ? Colors.grey.shade700 : Colors.black),
              textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER PARA TÍTULOS DE SEÇÃO ---
   Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  // --- WIDGET HELPER PARA OS INPUTS PRINCIPAIS DO FORMULÁRIO ---
  Widget _inputField(
      String label, TextEditingController controller, InputDecoration decoration,
      { bool readOnly = false, TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters, VoidCallback? onTap, Color? labelColor
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller, readOnly: readOnly, keyboardType: keyboardType,
        inputFormatters: inputFormatters, onTap: onTap,
        decoration: decoration.copyWith(
          labelText: label, fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          labelStyle: TextStyle(color: labelColor ?? (readOnly ? Colors.grey.shade700 : Colors.black54)),
        ),
        style: TextStyle(color: readOnly ? Colors.grey.shade700 : Colors.black),
      ),
    );
  }

 // --- WIDGET HELPER UNIFICADO PARA OS ITENS DO TOPO ---
 Widget _infoItem({
    required BuildContext context, required String title, required IconData icon,
    required TextEditingController displayController, VoidCallback? onTap,
 }) {
    final controller = Provider.of<ProfileController>(context);
    final bool isCurrentlyEditing = controller.isEditing;
    final bool isClickableWhenEditing = onTap != null;

    return Expanded(
      child: InkWell(
        onTap: isCurrentlyEditing && isClickableWhenEditing ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container( // Círculo do Ícone
                width: 60, height: 60,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent, // Cor sempre azul
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 8),
              Text( // Título
                title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Padding( // Valor
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  displayController.text.isNotEmpty ? displayController.text : '-',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              Opacity( // Ícone de Editar
                opacity: isCurrentlyEditing && isClickableWhenEditing ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(Icons.edit, size: 14, color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
 }

  // --- FUNÇÃO PARA O POP-UP DE EDIÇÃO GERAL (TEXTO) ---
  Future<void> _showEditInfoDialog({
    required BuildContext context, required String title, required TextEditingController targetController,
    TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters,
  }) async {
    final tempController = TextEditingController(text: targetController.text);
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context, barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Editar $title'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: tempController, keyboardType: keyboardType,
                inputFormatters: inputFormatters, autofocus: true,
                decoration: InputDecoration( hintText: 'Digite o novo valor', ),
                validator: (value) {
                  if (value == null || value.isEmpty) { return 'Campo não pode ser vazio'; }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Salvar'),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                    targetController.text = tempController.text;
                    // Aqui também precisaríamos do notifyListeners() para refletir na UI principal
                    Provider.of<ProfileController>(context, listen: false).notifyListeners();
                    Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

 // ========================================================================
 // NOVA FUNÇÃO PARA O POP-UP DE SELEÇÃO DE TIPO SANGUÍNEO
 // ========================================================================
 Future<void> _showBloodTypeSelectionDialog(BuildContext context, ProfileController controller) async {
    String? tipoSelecionadoTemporario = controller.sangueController.text; // Guarda o valor atual

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Usa StatefulBuilder para permitir a atualização dentro do dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Selecione o Tipo Sanguíneo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // Cria uma lista de RadioListTile para cada tipo sanguíneo
                  children: _tiposSanguineos.map((tipo) {
                    return RadioListTile<String>(
                      title: Text(tipo),
                      value: tipo,
                      groupValue: tipoSelecionadoTemporario,
                      onChanged: (String? value) {
                        // Atualiza o estado DENTRO do dialog
                        setDialogState(() {
                          tipoSelecionadoTemporario = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Fecha sem salvar
                  },
                ),
                ElevatedButton(
                  child: const Text('Salvar'),
                  onPressed: () {
                    // Atualiza o controller principal com o valor selecionado no dialog
                    if (tipoSelecionadoTemporario != null) {
                        controller.sangueController.text = tipoSelecionadoTemporario!;
                        
                        // ==============================================
                        // ADIÇÃO SOLICITADA:
                        // Notifica os listeners (como o Consumer) para
                        // redesenhar a UI imediatamente com o novo valor.
                        controller.notifyListeners(); 
                        // ==============================================
                    }
                    Navigator.of(dialogContext).pop(); // Fecha o dialog
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  ImageProvider _getProfileImage(ProfileController controller) {
    if (controller.pickedImage != null) {
      // 1. Prioridade: Exibe a imagem recém-selecionada (local)
      if (kIsWeb) {
      return NetworkImage(controller.pickedImage!.path);
    } else {
      return FileImage(File(controller.pickedImage!.path));
    }
  }
  if (controller.profileImageUrl != null && controller.profileImageUrl!.isNotEmpty) {
    // 2. Senão: Exibe a imagem vinda da API (rede)
    return NetworkImage(controller.profileImageUrl!);
  }
  // 3. Senão: Exibe o placeholder
  return const NetworkImage('https://via.placeholder.com/150');
}

  void _showImageSourceActionSheet(BuildContext context, ProfileController controller) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria'),
                onTap: () {
                  controller.pickImage(ImageSource.gallery);
                  Navigator.of(sheetContext).pop(); // Fecha o BottomSheet
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Câmera'),
                onTap: () {
                  controller.pickImage(ImageSource.camera);
                  Navigator.of(sheetContext).pop(); // Fecha o BottomSheet
                },
              ),
            ],
          ),
        );
      },
    );
  }


} // --- FIM DA CLASSE _PerfilPageState ---