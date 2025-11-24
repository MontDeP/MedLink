// lib/views/widgets/perfil/profile_body.dart (VERSÃO COMPLETA E CORRIGIDA)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:medlink/controllers/profile_controller.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
// import 'package:provider/provider'; // REMOVIDO: Uri does not exist & Unused
import 'profile_dialogs.dart';

class ProfileBody extends StatelessWidget {
  final ProfileController controller;
  final FocusNode cepFocusNode;
  final FocusNode dataNascimentoFocusNode; // <-- CORREÇÃO: Adicionado

  ProfileBody({
    super.key, // CORRIGIDO: Uso de super.key
    required this.controller,
    required this.cepFocusNode,
    required this.dataNascimentoFocusNode, // <-- CORREÇÃO: Adicionado
  });

  // Máscaras restantes:
  final _cpfMaskFormatter = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _dateMaskFormatter = MaskTextInputFormatter(
      mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

  // Função helper para extrair as iniciais do nome (Mantida e Corrigida)
  String _getInitials(String fullName) {
    // CORRIGIDO: removido fullName == null, pois String é non-nullable.
    if (fullName.isEmpty) return 'P'; 
    
    // Remove espaços desnecessários e divide o nome
    List<String> parts = fullName.trim().split(RegExp(r'\s+'));
    String initials = '';

    // Se houver apenas uma parte (ou seja, só o primeiro nome)
    if (parts.length == 1 && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }

    // Pega a primeira letra do primeiro nome
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials += parts[0][0].toUpperCase();
    }

    // Pega a primeira letra do último nome, ignorando nomes curtos (ex: "de", "da")
    if (parts.length > 1) {
      String lastName = parts.last;
      if (lastName.length > 1) {
        initials += lastName[0].toUpperCase();
      }
    }
    
    // Se o resultado for uma única letra (após filtros), usa ela. Se for mais, usa as duas.
    return initials.length >= 2 ? initials.substring(0, 2) : initials;
  }


  @override
  Widget build(BuildContext context) {
    final bool isReadOnly = !controller.isEditing;
    final String initials = _getInitials(controller.nomeCompletoController.text);
    final bool hasImage = controller.pickedImage != null || 
                          (controller.profileImageUrl != null && controller.profileImageUrl!.isNotEmpty);

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
                width: double.infinity,
                height: 100, // Retângulo de cima
                decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    )),
              ),
              Positioned(
                top: 30,
                child: Stack(
                  children: [
                    // LÓGICA DO AVATAR COM INICIAIS
                    CircleAvatar(
                      radius: 70,
                      // Cor de fundo padrão (ex: um azul mais forte)
                      backgroundColor: hasImage 
                          ? Colors.grey[300]! 
                          : Colors.blue.shade700, 
                      backgroundImage: hasImage 
                          ? _getProfileImage(controller) 
                          : null,
                      child: hasImage
                          ? null // Se tiver imagem, não mostra texto
                          : Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    // FIM DA LÓGICA DO AVATAR
                    if (controller.isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.edit,
                                size: 20, color: Colors.blue),
                            tooltip: 'Alterar foto',
                            onPressed: () {
                              showImageSourceActionSheet(context, controller);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // CORREÇÃO DE LAYOUT 1: Espaço atrás do avatar/nome
          const SizedBox(height: 100), 
          
          Center(
            child: Text(
              controller.nomeCompletoController.text.isNotEmpty
                  ? controller.nomeCompletoController.text
                  : "Nome do Usuário",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

          // CORREÇÃO DE LAYOUT 2: Espaço entre nome e ícones
          const SizedBox(height: 24),

          // --- Linha de Informações (Altura, Peso, Idade, Sangue) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoItem(
                context: context,
                title: 'Altura (cm)',
                icon: Icons.height,
                displayController: controller.alturaController,
                onTap: () => showEditInfoDialog(
                  context: context,
                  title: 'Altura (cm)',
                  targetController: controller.alturaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              _infoItem(
                context: context,
                title: 'Peso (kg)',
                icon: Icons.monitor_weight,
                displayController: controller.pesoController,
                onTap: () => showEditInfoDialog(
                  context: context,
                  title: 'Peso (kg)',
                  targetController: controller.pesoController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    // CORREÇÃO DO PESO: Aceita '.'
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[.]?\d{0,2}'))
                  ],
                ),
              ),
              _infoItem(
                context: context,
                title: 'Idade', 
                icon: Icons.cake,
                displayController: controller.idadeController,
                onTap: null, // Idade não é editável diretamente
              ),
              _infoItem(
                context: context,
                title: 'Sangue',
                icon: Icons.bloodtype,
                displayController: controller.sangueController,
                onTap: () => showBloodTypeSelectionDialog(context, controller),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Formulário ---
          _buildSectionTitle('Informações Pessoais'),
          _inputField('Nome Completo', controller.nomeCompletoController,
              inputDecoration,
              readOnly: isReadOnly),
          _inputField('CPF', controller.cpfController, inputDecoration,
              readOnly: true,
              labelColor: Colors.grey,
              inputFormatters: [_cpfMaskFormatter]),
          
          _inputField('Email', controller.emailController, inputDecoration,
              readOnly: isReadOnly, 
              labelColor: isReadOnly ? Colors.grey : null, 
              keyboardType: TextInputType.emailAddress,
          ),
          
          _inputField(
            'Telefone',
            controller.telefoneController,
            inputDecoration,
            readOnly: isReadOnly,
            keyboardType: TextInputType.phone,
            inputFormatters: [controller.phoneMaskFormatter], 
          ),
          
          // CORREÇÃO DATA NASCIMENTO: Digitável e com FocusNode
          _inputField(
            'Data Nascimento',
            controller.dataNascimentoController,
            inputDecoration,
            readOnly: isReadOnly, // <-- CORREÇÃO
            labelColor: isReadOnly ? Colors.grey : null,
            keyboardType: TextInputType.datetime,
            inputFormatters: [_dateMaskFormatter],
            onTap: null, // <-- CORREÇÃO
            focusNode: dataNascimentoFocusNode, // <-- CORREÇÃO
          ),

          _buildSectionTitle('Endereço'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.cepController,
                    focusNode: cepFocusNode,
                    readOnly: isReadOnly,
                    keyboardType: TextInputType.number,
                    inputFormatters: [controller.cepMaskFormatter],
                    decoration: inputDecoration.copyWith(
                      labelText: 'CEP',
                      fillColor:
                          isReadOnly ? Colors.grey.shade100 : Colors.white,
                      labelStyle: TextStyle(
                          color: isReadOnly
                              ? Colors.grey.shade700
                              : Colors.black54),
                      hintText: '00000-000',
                    ),
                    style: TextStyle(
                        color: isReadOnly ? Colors.grey.shade700 : Colors.black),
                  ),
                ),
                if (controller.isEditing)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                    child: controller.isCepLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.search, color: Colors.blue),
                            onPressed: controller.buscarCep,
                            tooltip: 'Buscar Endereço',
                          ),
                  ),
              ],
            ),
          ),
          if (controller.errorMessage != null &&
              (controller.errorMessage?.toLowerCase().contains('cep') ?? false))
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(controller.errorMessage!,
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),

          _inputField('Bairro', controller.bairroController, inputDecoration,
              readOnly: isReadOnly),
          _inputField('Av/Rua', controller.avRuaController, inputDecoration,
              readOnly: isReadOnly),
          _inputField('Número', controller.numeroController, inputDecoration,
              readOnly: isReadOnly),

          _buildSectionTitle('Informações Adicionais'),
          TextFormField(
            controller: controller.infoAdicionaisController,
            readOnly: isReadOnly,
            maxLines: 5,
            minLines: 3,
            decoration: inputDecoration.copyWith(
              hintText: 'Alergias, condições pré-existentes, etc.',
              fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
              alignLabelWithHint: true,
              labelText: 'Notas Adicionais',
            ),
            style: TextStyle(
                color: isReadOnly ? Colors.grey.shade700 : Colors.black),
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  // --- HELPER METHODS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  // CORREÇÃO DE SINTAXE: 'focusNode' adicionado
  Widget _inputField(String label, TextEditingController controller,
      InputDecoration decoration,
      {bool readOnly = false,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters,
      VoidCallback? onTap,
      Color? labelColor,
      FocusNode? focusNode, // <-- CORREÇÃO
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onTap: onTap,
        focusNode: focusNode, // <-- CORREÇÃO
        decoration: decoration.copyWith(
          labelText: label,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          labelStyle: TextStyle(
              color: labelColor ??
                  (readOnly ? Colors.grey.shade700 : Colors.black54)),
        ),
        style:
            TextStyle(color: readOnly ? Colors.grey.shade700 : Colors.black),
      ),
    );
  }

  Widget _infoItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required TextEditingController displayController,
    VoidCallback? onTap,
  }) {
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
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  displayController.text.isNotEmpty
                      ? displayController.text
                      : '-',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Opacity(
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

  ImageProvider? _getProfileImage(ProfileController controller) {
    if (controller.pickedImage != null) {
      if (kIsWeb) {
        return NetworkImage(controller.pickedImage!.path);
      } else {
        // CORREÇÃO: Necessário usar FileImage se não for web
        return FileImage(File(controller.pickedImage!.path));
      }
    }
    if (controller.profileImageUrl != null &&
        controller.profileImageUrl!.isNotEmpty) {
      return NetworkImage(controller.profileImageUrl!);
    }
    // Retorna null, pois o widget pai (CircleAvatar) irá exibir o Text com as iniciais.
    return null;
  }
}