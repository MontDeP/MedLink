// lib/views/widgets/perfil/profile_dialogs.dart (ATUALIZADO)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medlink/controllers/profile_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// --- FUNÇÃO PARA O POP-UP DE EDIÇÃO GERAL (TEXTO) ---
Future<void> showEditInfoDialog({
  // ... (esta função continua a mesma)
  required BuildContext context,
  required String title,
  required TextEditingController targetController,
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter>? inputFormatters,
}) async {
  final tempController = TextEditingController(text: targetController.text);
  final formKey = GlobalKey<FormState>();

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('Editar $title'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: tempController,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Digite o novo valor',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Campo não pode ser vazio';
                }
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
                // Notifica a UI principal para atualizar o valor
                Provider.of<ProfileController>(context, listen: false)
                    .notifyListeners();
                Navigator.of(dialogContext).pop();
              }
            },
          ),
        ],
      );
    },
  );
}

// CORREÇÃO 5: Adicionado 'Não sei'
final List<String> _tiposSanguineos = [
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
  'Não sei', // ADICIONADO
];

// --- FUNÇÃO PARA O POP-UP DE SELEÇÃO DE TIPO SANGUÍNEO ---
Future<void> showBloodTypeSelectionDialog(
    BuildContext context, ProfileController controller) async {
      
  // CORREÇÃO 5: Se o valor salvo for "", seleciona "Não sei" no dialog
  String? tipoSelecionadoTemporario = controller.sangueController.text;
  if (tipoSelecionadoTemporario.isEmpty) {
    tipoSelecionadoTemporario = 'Não sei';
  }

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Selecione o Tipo Sanguíneo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _tiposSanguineos.map((tipo) {
                  return RadioListTile<String>(
                    title: Text(tipo),
                    value: tipo,
                    groupValue: tipoSelecionadoTemporario,
                    onChanged: (String? value) {
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
                  Navigator.of(dialogContext).pop();
                },
              ),
              ElevatedButton(
                child: const Text('Salvar'),
                onPressed: () {
                  if (tipoSelecionadoTemporario != null) {
                    // CORREÇÃO 5: Se 'Não sei' for selecionado, salva string vazia
                    controller.sangueController.text =
                        (tipoSelecionadoTemporario == 'Não sei')
                            ? ''
                            : tipoSelecionadoTemporario!;
                    
                    controller.notifyListeners();
                  }
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}

// --- FUNÇÃO PARA O POP-UP DE SELEÇÃO DE IMAGEM ---
void showImageSourceActionSheet(
    BuildContext context, ProfileController controller) {
  // ... (esta função continua a mesma)
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
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () {
                controller.pickImage(ImageSource.camera);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}