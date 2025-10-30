// lib/controllers/profile_controller.dart
import 'package:flutter/material.dart';
import 'package:medlink/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // 1. IMPORT ADICIONADO

class ProfileController extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // 2. ADIÇÕES PARA IMAGE PICKER
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage; // Guarda a imagem selecionada (arquivo)
  String? _profileImageUrl; // Guarda a URL da imagem vinda da API

  // Getters para a UI
  XFile? get pickedImage => _pickedImage;
  String? get profileImageUrl => _profileImageUrl;

  // Controladores de estado da UI
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;
  bool _isCepLoading = false; // Loading para busca de CEP

  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isCepLoading => _isCepLoading;

  // Controladores de texto
  final nomeCompletoController = TextEditingController();
  final cpfController = TextEditingController();
  final emailController = TextEditingController();
  String _firstName = '';
  String _lastName = '';
  final telefoneController = TextEditingController();
  final alturaController = TextEditingController();
  final pesoController = TextEditingController();
  final idadeController = TextEditingController();
  final dataNascimentoController = TextEditingController(); // Display DD/MM/YYYY
  final sangueController = TextEditingController();
  final cepController = TextEditingController(); // Controller para o CEP
  final bairroController = TextEditingController();
  final quadraController = TextEditingController(); // Ainda precisa deste?
  final avRuaController = TextEditingController();
  final numeroController = TextEditingController();
  final infoAdicionaisController = TextEditingController();

  // Armazena a data de nascimento no formato da API (YYYY-MM-DD)
  String? _dataNascimentoApi;
  DateTime? _parsedDataNascimento;
  DateTime? get parsedDataNascimento => _parsedDataNascimento;

  // Máscara para o CEP (para aplicar ao carregar e formatar entrada)
  final _cepMaskFormatter = MaskTextInputFormatter(
    mask: '#####-###', filter: {"#": RegExp(r'[0-9]')}
  );
  // Getter para a UI usar a máscara formatada
  MaskTextInputFormatter get cepMaskFormatter => _cepMaskFormatter;


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
    cepController.dispose(); // Dispose do CEP controller
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
    _pickedImage = null; // 3. Reseta a imagem selecionada ao recarregar
    notifyListeners();

    try {
      final data = await _apiService.getPacienteProfile();
      final userData = data['user'] as Map<String, dynamic>;

      _firstName = userData['first_name'] ?? '';
      _lastName = userData['last_name'] ?? '';
      nomeCompletoController.text = userData['nome_completo'] ?? '';
      cpfController.text = userData['cpf'] ?? ''; // TODO: Adicionar máscara de CPF aqui se desejar
      emailController.text = userData['email'] ?? '';
      telefoneController.text = data['telefone'] ?? ''; // TODO: Adicionar máscara de Telefone aqui
      alturaController.text = data['altura_cm']?.toString() ?? '';
      pesoController.text = data['peso_kg']?.toString() ?? '';
      _dataNascimentoApi = data['data_nascimento'];
      _updateIdadeEDisplayDataNascimento();
      sangueController.text = data['tipo_sanguineo'] ?? '';

      // 4. GUARDE A URL DA IMAGEM VINDA DA API
      // (Substitua 'profile_image_url' pelo nome real do campo na sua API)
      _profileImageUrl = data['profile_image_url'];

      // Aplica máscara ao CEP vindo da API
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
              if (hoje.month < dataNasc.month || (hoje.month == dataNasc.month && hoje.day < dataNasc.day)) {
                  idade--;
              }
              idadeController.text = idade >= 0 ? '$idade anos' : '-'; // Garante idade não negativa
              dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(dataNasc);
          } catch (e) {
              debugPrint("Erro ao parsear data de nascimento '$_dataNascimentoApi': $e");
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
      // _parsedDataNascimento é atualizado por _updateIdadeEDisplay...
      _updateIdadeEDisplayDataNascimento();
      notifyListeners();
  }

  void startEditing() {
    _isEditing = true;
    notifyListeners();
  }

  // --- Método Buscar Endereço pelo CEP ---
  Future<void> buscarCep() async {
    // Pega o texto do controller e remove a máscara antes de validar
    final cepValue = _cepMaskFormatter.unmaskText(cepController.text);

    if (cepValue.length != 8 || _isCepLoading) {
       if (cepValue.isNotEmpty && cepValue.length != 8) {
           _errorMessage = "CEP inválido. Deve conter 8 dígitos.";
           notifyListeners(); // Mostra o erro imediatamente
       }
      return; // Não busca se já estiver buscando ou se o CEP limpo não tiver 8 dígitos
    }

    _isCepLoading = true;
    _errorMessage = null; // Limpa erros anteriores
    notifyListeners();

    try {
      debugPrint("Buscando endereço para o CEP: $cepValue"); // Log
      final address = await _apiService.fetchAddressFromCep(cepValue); // Envia CEP limpo

      if (address != null) {
        debugPrint("Endereço encontrado: Bairro=${address.bairro}, Rua=${address.logradouro}"); // Log
        // Preenche os controllers com os dados da API
        bairroController.text = address.bairro;
        avRuaController.text = address.logradouro;
        // Limpa Quadra, pois ViaCEP não retorna isso
        quadraController.text = '';
        // Opcional: Preencher cidade/estado se tiver esses campos
        // cidadeController.text = address.localidade;
        // estadoController.text = address.uf;

         // Formata o CEP no controller APÓS a busca bem sucedida (caso o usuário tenha digitado sem máscara)
         cepController.text = _cepMaskFormatter.maskText(address.cep);

      } else {
        // Informa ao usuário se o CEP não for encontrado ou for inválido
         debugPrint("CEP $cepValue não encontrado ou inválido pela API."); // Log
        _errorMessage = "CEP não encontrado ou inválido.";
        // Limpa os campos caso o CEP seja inválido após preenchimento anterior
        bairroController.text = '';
        avRuaController.text = '';
        quadraController.text = '';
      }
    } catch (e) {
      _errorMessage = "Erro ao buscar CEP. Verifique a conexão.";
      debugPrint("Exceção em buscarCep: $e"); // Log de exceção
       // Limpa os campos em caso de erro de conexão
        bairroController.text = '';
        avRuaController.text = '';
        quadraController.text = '';
    } finally {
      _isCepLoading = false;
      notifyListeners();
    }
  }

  // 5. ADICIONE O MÉTODO PARA SELECIONAR A IMAGEM
  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        _pickedImage = image;
        _errorMessage = null; // Limpa erros (como erro de CEP)
        notifyListeners(); // Notifica a UI para exibir a nova imagem
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
    _lastName = nomeCompletoParts.length > 1 ? nomeCompletoParts.sublist(1).join(' ') : '';
    if (_firstName.isEmpty) {
        _errorMessage = "Por favor, insira pelo menos o primeiro nome.";
        _isSaving = false;
        notifyListeners();
        return false;
    }

    int? alturaCm = int.tryParse(alturaController.text);
    // Permite vírgula ou ponto no peso e converte para double
    double? pesoKg = double.tryParse(pesoController.text.replaceAll(',', '.'));

    // Pega o valor do CEP controller e remove a máscara antes de enviar
    String cepLimpo = _cepMaskFormatter.unmaskText(cepController.text);

    final Map<String, dynamic> dataToSave = {
        "user": {
            "first_name": _firstName,
            "last_name": _lastName,
        },
        "telefone": telefoneController.text, // TODO: Considerar limpar/validar telefone
        "altura_cm": alturaCm,
        "peso_kg": pesoKg,
        "data_nascimento": _dataNascimentoApi, // Formato YYYY-MM-DD
        "tipo_sanguineo": sangueController.text.toUpperCase(),
        "cep": cepLimpo, // Envia CEP sem máscara
        "bairro": bairroController.text,
        "quadra": quadraController.text, // Mantido campo Quadra
        "av_rua": avRuaController.text,
        "numero": numeroController.text,
        "informacoes_adicionais": infoAdicionaisController.text,
    };
     debugPrint("Dados para salvar: ${jsonEncode(dataToSave)}"); // Log dos dados
     
    try {
      // NOTA: A lógica de upload do arquivo de imagem (_pickedImage)
      // geralmente precisa ser feita em uma chamada separada (multipart request)
      // antes ou depois de salvar os outros dados, dependendo da sua API.
      // Ex: if (_pickedImage != null) { await _apiService.uploadProfilePicture(_pickedImage!); }

      await _apiService.updatePacienteProfile(dataToSave);
      _isEditing = false;
      _isSaving = false;
      _pickedImage = null; // Limpa a imagem selecionada após salvar
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