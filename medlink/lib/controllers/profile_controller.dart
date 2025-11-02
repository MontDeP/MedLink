// lib/controllers/profile_controller.dart (COM A CORREÇÃO DO 'TypeError')
import 'package:flutter/material.dart';
import 'package:medlink/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class ProfileController extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  String? _profileImageUrl;

  XFile? get pickedImage => _pickedImage;
  String? get profileImageUrl => _profileImageUrl;

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;
  bool _isCepLoading = false;

  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isCepLoading => _isCepLoading;

  final nomeCompletoController = TextEditingController();
  final cpfController = TextEditingController();
  final emailController = TextEditingController();
  String _firstName = '';
  String _lastName = '';
  final telefoneController = TextEditingController();
  final alturaController = TextEditingController();
  final pesoController = TextEditingController();
  final idadeController = TextEditingController();
  final dataNascimentoController = TextEditingController();
  final sangueController = TextEditingController();
  final cepController = TextEditingController();
  final bairroController = TextEditingController();
  final quadraController = TextEditingController();
  final avRuaController = TextEditingController();
  final numeroController = TextEditingController();
  final infoAdicionaisController = TextEditingController();

  String? _dataNascimentoApi;
  DateTime? _parsedDataNascimento;
  DateTime? get parsedDataNascimento => _parsedDataNascimento;

  final _cepMaskFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
  );
  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  MaskTextInputFormatter get cepMaskFormatter => _cepMaskFormatter;
  MaskTextInputFormatter get phoneMaskFormatter => _phoneMaskFormatter;

  ProfileController() {
    fetchProfile();
  }

  @override
  void dispose() {
    nomeCompletoController.dispose();
    cpfController.dispose();
    emailController.dispose();
    telefoneController.dispose();
    alturaController.dispose();
    pesoController.dispose();
    idadeController.dispose();
    dataNascimentoController.dispose();
    sangueController.dispose();
    cepController.dispose();
    bairroController.dispose();
    quadraController.dispose();
    avRuaController.dispose();
    numeroController.dispose();
    infoAdicionaisController.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    _pickedImage = null;
    notifyListeners();

    try {
      final data = await _apiService.getPacienteProfile();
      final userData = data['user'] as Map<String, dynamic>;

      _firstName = userData['first_name'] ?? '';
      _lastName = userData['last_name'] ?? '';
      nomeCompletoController.text = userData['nome_completo'] ?? '';
      cpfController.text = userData['cpf'] ?? '';
      emailController.text = userData['email'] ?? '';

      final phoneFromApi = data['telefone'] ?? '';
      telefoneController.text = _phoneMaskFormatter.maskText(phoneFromApi);

      // --- INÍCIO DA CORREÇÃO DO ERRO ---
      // (Esta lógica foi a que eu te passei na resposta anterior ao refactor)
      final alturaCm = data['altura_cm']?.toString() ?? '';
      final pesoKg = data['peso_kg']; // É 'dynamic' (pode ser String ou num)

      alturaController.text = alturaCm;

      if (pesoKg != null) {
        double? pesoDouble;
        if (pesoKg is num) {
          // Caso 1: A API manda um número (ex: 78 ou 78.0)
          pesoDouble = pesoKg.toDouble();
        } else if (pesoKg is String) {
          // Caso 2: A API manda um texto (ex: "78.00" ou "78,0")
          // Trocamos vírgula por ponto e tentamos converter
          pesoDouble = double.tryParse(pesoKg.replaceAll(',', '.'));
        }

        // Se conseguimos converter, formatamos para o padrão BR (com vírgula)
        if (pesoDouble != null) {
          pesoController.text = pesoDouble.toStringAsFixed(2);
        } else {
          // Se falhar, apenas mostramos o que veio
          pesoController.text = pesoKg.toString();
        }
      } else {
        pesoController.text = ''; // Se for nulo
      }
      // --- FIM DA CORREÇÃO DO ERRO ---

      _dataNascimentoApi = data['data_nascimento'];
      _updateIdadeEDisplayDataNascimento();
      sangueController.text = data['tipo_sanguineo'] ?? '';
      _profileImageUrl = data['profile_image_url'];

      final cepFromApi = data['cep'] ?? '';
      cepController.text = _cepMaskFormatter.maskText(cepFromApi);
      bairroController.text = data['bairro'] ?? '';
      quadraController.text = data['quadra'] ?? '';
      avRuaController.text = data['av_rua'] ?? '';
      numeroController.text = data['numero'] ?? '';
      infoAdicionaisController.text = data['informacoes_adicionais'] ?? '';
    } catch (e) {
      debugPrint("Erro ao buscar perfil: $e");
      _errorMessage = "Erro ao carregar o perfil. Tente novamente.";
    }

    _isLoading = false;
    notifyListeners();
  }

  void _updateIdadeEDisplayDataNascimento() {
    _parsedDataNascimento = null;
    if (_dataNascimentoApi != null && _dataNascimentoApi!.isNotEmpty) {
      try {
        final dataNasc = DateFormat('yyyy-MM-dd').parse(_dataNascimentoApi!);
        _parsedDataNascimento = dataNasc;

        final hoje = DateTime.now();
        int idade = hoje.year - dataNasc.year;
        if (hoje.month < dataNasc.month ||
            (hoje.month == dataNasc.month && hoje.day < dataNasc.day)) {
          idade--;
        }
        idadeController.text = idade >= 0 ? '$idade anos' : '-';
        dataNascimentoController.text = DateFormat(
          'dd/MM/yyyy',
        ).format(dataNasc);
      } catch (e) {
        debugPrint(
          "Erro ao parsear data de nascimento '$_dataNascimentoApi': $e",
        );
        idadeController.text = '-';
        dataNascimentoController.text = '';
        _parsedDataNascimento = null;
      }
    } else {
      idadeController.text = '-';
      dataNascimentoController.text = '';
      _parsedDataNascimento = null;
    }
  }

  void setDataNascimento(DateTime novaData) {
    _dataNascimentoApi = DateFormat('yyyy-MM-dd').format(novaData);
    _updateIdadeEDisplayDataNascimento();
    notifyListeners();
  }

  void updateAgeFromTextField() {
    final text = dataNascimentoController.text;

    // Verifica se a data está completa (dd/mm/yyyy = 10 chars)
    if (text.length == 10) {
      try {
        // 1. Converte o texto 'dd/MM/yyyy' para um objeto DateTime
        final dataNasc = DateFormat('dd/MM/yyyy').parse(text);

        // 2. Chama a função que já temos. Ela vai:
        //    - Atualizar a variável _dataNascimentoApi (para salvar)
        //    - Chamar _updateIdadeEDisplayDataNascimento() (para calcular a idade)
        //    - Chamar notifyListeners() (para atualizar a UI)
        setDataNascimento(dataNasc);
      } catch (e) {
        // Se a data for inválida (ex: 99/99/9999)
        debugPrint("Erro ao parsear data digitada: $e");
        _dataNascimentoApi = null;
        _parsedDataNascimento = null;
        idadeController.text = '-'; // Limpa a idade
        notifyListeners();
      }
    } else if (text.isEmpty) {
      // Se o campo for apagado, limpa a idade
      _dataNascimentoApi = null;
      _parsedDataNascimento = null;
      idadeController.text = '-';
      notifyListeners();
    }
    // Se a data estiver incompleta (ex: "12/03/"), não faz nada
    // e espera o usuário terminar de digitar.
  }

  void startEditing() {
    _isEditing = true;
    notifyListeners();
  }

  Future<void> buscarCep() async {
    final cepValue = _cepMaskFormatter.unmaskText(cepController.text);
    if (cepValue.length != 8 || _isCepLoading) {
      if (cepValue.isNotEmpty && cepValue.length != 8) {
        _errorMessage = "CEP inválido. Deve conter 8 dígitos.";
        notifyListeners();
      }
      return;
    }
    _isCepLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final address = await _apiService.fetchAddressFromCep(cepValue);
      if (address != null) {
        bairroController.text = address.bairro;
        avRuaController.text = address.logradouro;
        quadraController.text = '';
        cepController.text = _cepMaskFormatter.maskText(address.cep);
      } else {
        _errorMessage = "CEP não encontrado ou inválido.";
        bairroController.text = '';
        avRuaController.text = '';
        quadraController.text = '';
      }
    } catch (e) {
      _errorMessage = "Erro ao buscar CEP. Verifique a conexão.";
      debugPrint("Exceção em buscarCep: $e");
      bairroController.text = '';
      avRuaController.text = '';
      quadraController.text = '';
    } finally {
      _isCepLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        _pickedImage = image;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Erro ao selecionar imagem: $e");
      _errorMessage = "Erro ao selecionar imagem. Verifique as permissões.";
      notifyListeners();
    }
  }

  Future<bool> saveProfile() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final nomeCompletoParts = nomeCompletoController.text.trim().split(' ');
    _firstName = nomeCompletoParts.isNotEmpty ? nomeCompletoParts.first : '';
    _lastName = nomeCompletoParts.length > 1
        ? nomeCompletoParts.sublist(1).join(' ')
        : '';
    if (_firstName.isEmpty) {
      _errorMessage = "Por favor, insira pelo menos o primeiro nome.";
      _isSaving = false;
      notifyListeners();
      return false;
    }

    int? alturaCm = int.tryParse(alturaController.text);
    double? pesoKg = double.tryParse(pesoController.text.replaceAll(',', '.'));
    String telefoneLimpo = _phoneMaskFormatter.unmaskText(
      telefoneController.text,
    );
    String cepLimpo = _cepMaskFormatter.unmaskText(cepController.text);

    final Map<String, dynamic> dataToSave = {
      "user": {
        "first_name": _firstName,
        "last_name": _lastName,
        "email": emailController.text,
      },
      "telefone": telefoneLimpo,
      "altura_cm": alturaCm,
      "peso_kg": pesoKg,
      "data_nascimento": _dataNascimentoApi,
      "tipo_sanguineo": sangueController.text.toUpperCase(),
      "cep": cepLimpo,
      "bairro": bairroController.text,
      "quadra": quadraController.text,
      "av_rua": avRuaController.text,
      "numero": numeroController.text,
      "informacoes_adicionais": infoAdicionaisController.text,
    };
    debugPrint("Dados para salvar: ${jsonEncode(dataToSave)}");

    try {
      await _apiService.updatePacienteProfile(dataToSave);

      if (pesoKg != null) {
        pesoController.text = pesoKg.toStringAsFixed(2);
      }

      _isEditing = false;
      _isSaving = false;
      _pickedImage = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Erro ao salvar perfil: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains("Exception: ")) {
        errorMsg = errorMsg.replaceFirst("Exception: ", "");
      }
      _errorMessage = "Erro ao salvar: $errorMsg";
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
