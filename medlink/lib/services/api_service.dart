import 'dart:convert';
import 'package:flutter/foundation.dart'; // Importado para usar debugPrint
import 'package:http/http.dart' as http;
import 'package:medlink/views/pages/admin.dart'; // AdminUser
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../models/dashboard_stats_model.dart';
import '../models/patient_model.dart';
import '../models/doctor_model.dart';
import '../models/paciente.dart'; // Paciente (do médico)
import '../models/consultas.dart' as consultas_model;
import '../models/dashboard_data_model.dart'; // DashboardData (do paciente)

class ApiService {
  // ✅ Base URL unificada
  final String baseUrl = kIsWeb
      ? "http://127.0.0.1:8000" // Para Web
      : "http://10.0.2.2:8000"; // Para Emulador Android (verifique se é seu caso)

  static String? _accessToken; // Token JWT salvo após o login

  // --- MÉTODOS DE AUTENTICAÇÃO ---

  Future<Map<String, dynamic>?> login(String cpf, String password) async {
    final url = Uri.parse("$baseUrl/api/token/"); // Endpoint de login JWT
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cpf": cpf, "password": password}), // Envia CPF e senha
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access']; // Salva o token de acesso estaticamente
        final String? userType = _getUserTypeFromToken(_accessToken!);

        return {
          'success': true,
          'access_token': data['access'],
          'refresh_token': data['refresh'],
          'user_type': userType ?? 'unknown', // Retorna o tipo de usuário
        };
      } else {
        // Retorna falha com detalhes do erro
        return {
          'success': false,
          'status_code': response.statusCode,
          'body': response.body,
        };
      }
    } catch (e) {
      debugPrint('Erro na chamada de login: $e');
      return {'success': false, 'error': e.toString()}; // Retorna falha de conexão/geral
    }
  }

  // Helper para extrair o tipo de usuário do token JWT
  String? _getUserTypeFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Token JWT inválido');
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      return payloadMap['user_type']; // Pega o campo 'user_type' do payload
    } catch (e) {
      debugPrint('Erro ao decodificar token: $e');
      return null;
    }
  }

  // --- MÉTODOS DE RECUPERAÇÃO DE SENHA ---

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final url = Uri.parse('$baseUrl/api/users/request-password-reset/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      // ... (lógica de tratamento de sucesso/erro) ...
        if (response.statusCode == 200) {
            return {'success': true, 'message': 'E-mail de recuperação enviado.'};
        } else {
            try {
              final responseBody = json.decode(utf8.decode(response.bodyBytes));
              return {'success': false, 'message': responseBody['error'] ?? 'E-mail não encontrado ou inválido.'};
            } catch (e) {
              return {'success': false, 'message': 'Erro ao processar resposta do servidor. Status: ${response.statusCode}'};
            }
        }
    } catch (e) {
      debugPrint('Erro de conexão em requestPasswordReset: $e');
      return {'success': false, 'message': 'Não foi possível conectar ao servidor. Verifique sua internet.'};
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset(String uid, String token, String password) async {
    final url = Uri.parse('$baseUrl/api/users/reset-password-confirm/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': uid, 'token': token, 'password': password}),
      );
      // ... (lógica de tratamento de sucesso/erro) ...
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Senha redefinida com sucesso.'};
      } else {
        try {
          final responseBody = json.decode(utf8.decode(response.bodyBytes));
          String errorMessage = "Token inválido ou expirado.";
          if (responseBody is Map) {
            final errors = responseBody.values.first;
            if (errors is List) {
              errorMessage = errors.first;
            } else {
              errorMessage = errors.toString();
            }
          }
          return {'success': false, 'message': errorMessage};
        } catch (e) {
          return {'success': false, 'message': 'Erro no servidor. Status: ${response.statusCode}'};
        }
      }
    } catch (e) {
      debugPrint('Erro de conexão em confirmPasswordReset: $e');
      return {'success': false, 'message': 'Não foi possível conectar ao servidor.'};
    }
  }

  Future<Map<String, dynamic>> createPasswordConfirm(String uid, String token, String password) async {
      final url = Uri.parse('$baseUrl/api/users/create-password-confirm/');
      try {
        final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'uid': uid, 'token': token, 'password': password}),
        );
        if (response.statusCode == 200) {
            return {'success': true, 'message': 'Senha definida com sucesso.'};
        } else {
            final errorData = jsonDecode(utf8.decode(response.bodyBytes));
            return {'success': false, 'message': errorData['error'] ?? 'Link inválido ou expirado'};
        }
      } catch (e) {
         debugPrint('Erro de conexão em createPasswordConfirm: $e');
         return {'success': false, 'message': 'Não foi possível conectar ao servidor.'};
      }
  }


  // --- MÉTODOS PARA PACIENTES ---

  // Registro de Paciente (via formulário de cadastro)
  Future<bool> register(User user) async {
    final parts = user.username.split(' ');
    final firstName = parts.isNotEmpty ? parts.first : user.username;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final response = await http.post(
      Uri.parse("$baseUrl/api/pacientes/register/"), // Endpoint de registro
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "cpf": user.cpf,
        "email": user.email,
        "password": user.password,
        "first_name": firstName,
        "last_name": lastName,
        "telefone": user.telefone,
      }),
    );
    return response.statusCode == 201; // 201 Created indica sucesso
  }

  // Busca dados para o Dashboard do Paciente
  Future<DashboardData> fetchDashboardData() async {
    final url = Uri.parse("$baseUrl/api/pacientes/dashboard/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return DashboardData.fromJson(data); // Usa o factory do modelo
    } else {
      debugPrint('Falha no Dashboard Paciente: ${response.statusCode} | ${response.body}');
      throw Exception('Falha ao carregar dados do dashboard do paciente');
    }
  }

  // Busca o perfil completo do paciente logado
  Future<Map<String, dynamic>> getPacienteProfile() async {
    final url = Uri.parse("$baseUrl/api/pacientes/profile/"); // Endpoint do perfil
    if (_accessToken == null) throw Exception('Token de acesso não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken", // Envia o token
      },
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)); // Retorna o JSON do perfil
    } else {
      throw Exception('Falha ao carregar perfil: ${response.statusCode}');
    }
  }

  // Atualiza o perfil do paciente logado
  Future<Map<String, dynamic>> updatePacienteProfile(Map<String, dynamic> profileData) async {
    final url = Uri.parse("$baseUrl/api/pacientes/profile/");
    if (_accessToken == null) throw Exception('Token de acesso não encontrado.');

    final response = await http.patch( // Usa PATCH para atualização parcial
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode(profileData), // Envia os dados a serem atualizados
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)); // Retorna o perfil atualizado
    } else {
      debugPrint('Erro ao atualizar perfil (${response.statusCode}): ${response.body}');
      throw Exception('Falha ao atualizar perfil');
    }
  }

  // Busca lista de pacientes (usado pela secretária e admin)
  Future<List<Patient>> getPatients(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/pacientes/");
     final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    // ... (lógica de tratamento de sucesso/erro) ...
     if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => Patient.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar pacientes (Status: ${response.statusCode})');
    }
  }

   // Cria um novo paciente (usado pela secretária)
  Future<http.Response> createPatient(
    Map<String, dynamic> patientData,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/pacientes/register/"); // Reutiliza endpoint de registro
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken', // Secretária precisa estar autenticada
      },
      body: jsonEncode(patientData),
    );
  }


  // --- MÉTODOS PARA MÉDICOS ---

  // Busca pacientes agendados para o médico logado HOJE
  Future<List<Paciente>> getPacientesDoDia() async {
    final url = Uri.parse("$baseUrl/api/pacientes/hoje/"); // Endpoint específico
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      // Usa o modelo Paciente (que inclui detalhes da consulta de hoje)
      return body.map((e) => Paciente.fromJson(e)).toList();
    } else {
      throw Exception('Falha ao carregar pacientes do dia: ${response.statusCode}');
    }
  }

   // Busca o histórico de consultas de um paciente específico PARA o médico logado
  Future<List<consultas_model.Consulta>> getHistoricoConsultas(int pacienteId) async {
    final url = Uri.parse("$baseUrl/api/pacientes/$pacienteId/historico/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((json) => consultas_model.Consulta.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar o histórico: ${response.statusCode}');
    }
  }

  // Busca a agenda do médico logado para um mês/ano específico
  Future<Map<String, List<dynamic>>> getMedicoAgenda(int year, int month) async {
    final url = Uri.parse("$baseUrl/api/medicos/agenda/?year=$year&month=$month");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      // A API retorna chave como "YYYY-MM-DD", o front trata
      return body.map((key, value) => MapEntry(key, value as List<dynamic>));
    } else {
      throw Exception('Falha ao carregar a agenda: ${response.statusCode}');
    }
  }

  // Busca lista de médicos (usado pela secretária e admin)
  Future<List<Doctor>> getDoctors(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/medicos/");
     final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
     // ... (lógica de tratamento de sucesso/erro) ...
     if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => Doctor.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar médicos (Status: ${response.statusCode})');
    }
  }


  // --- MÉTODOS PARA CONSULTAS / AGENDAMENTOS ---

  // Busca anotação de uma consulta específica
  Future<String?> getAnotacao(int consultaId) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$consultaId/anotacao/");
    if (_accessToken == null) return null; // Retorna nulo se não logado

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $_accessToken"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['conteudo']; // Retorna o conteúdo da anotação
    }
    if (response.statusCode == 404) {
      return ""; // Retorna string vazia se anotação não existe (404 Not Found)
    }
    throw Exception('Falha ao carregar anotação.'); // Outros erros
  }

  // Salva (cria ou atualiza) anotação de uma consulta
  Future<void> salvarAnotacao(int consultaId, String conteudo) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$consultaId/anotacao/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.post( // Endpoint usa POST para criar/atualizar
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode({'conteudo': conteudo}), // Envia o conteúdo
    );

    // Verifica se deu certo (200 OK ou 201 Created)
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao salvar anotação.');
    }
  }

   // Finaliza uma consulta (médico)
  Future<bool> finalizarConsulta(int consultaId, String conteudo) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$consultaId/finalizar/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.post( // Endpoint de finalização
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode({'conteudo': conteudo}), // Salva a anotação final
    );

    return response.statusCode == 200; // Retorna true se sucesso (200 OK)
  }

  // Cria um novo agendamento (secretária)
  Future<http.Response> createAppointment(Appointment appointment, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/");
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(appointment.toJson()), // Usa o toJson do modelo Appointment
    );
  }

  // Busca agendamentos de HOJE (secretária)
  Future<List<Appointment>> getAppointments(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/dashboard/consultas-hoje/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    // ... (lógica de tratamento de sucesso/erro) ...
     if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => Appointment.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar agendamentos (Status: ${response.statusCode})');
    }
  }

  // Confirma um agendamento (secretária)
  Future<http.Response> confirmAppointment(int appointmentId, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/consultas/$appointmentId/confirmar/");
    return await http.patch( // Usa PATCH para mudar o status
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  // Cancela um agendamento (secretária)
  Future<http.Response> cancelAppointment(int appointmentId, String reason, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/consultas/$appointmentId/cancelar/");
    return await http.patch( // Usa PATCH
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'motivo': reason}), // Envia o motivo
    );
  }

  // Atualiza (remarca) um agendamento (secretária)
  Future<http.Response> updateAppointment(int appointmentId, DateTime newDateTime, String accessToken) async {
    // Atenção: O endpoint correto pode ser /api/agendamentos/<id>/ ou um específico da secretária
    final url = Uri.parse("$baseUrl/api/agendamentos/$appointmentId/");
    return await http.put( // Usamos PUT ou PATCH dependendo da API
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'data_hora': newDateTime.toIso8601String()}), // Envia a nova data/hora
    );
  }

  // --- MÉTODOS PARA SECRETÁRIA (Dashboard) ---

  // Busca estatísticas do dashboard da secretária
  Future<DashboardStats> getDashboardStats(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/dashboard/stats/");
     final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
     // ... (lógica de tratamento de sucesso/erro) ...
      if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "{}") {
        return DashboardStats(today: 0, confirmed: 0, pending: 0, totalMonth: 0);
      }
      return DashboardStats.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Falha ao carregar estatísticas do dashboard.');
    }
  }

  // --- MÉTODOS PARA ADMIN ---

  // Busca todos os usuários da clínica (médicos, secretárias, etc.)
  Future<List<AdminUser>> getClinicUsers(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/");
     final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
     // ... (lógica de tratamento de sucesso/erro) ...
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => AdminUser.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar usuários (Status: ${response.statusCode})');
    }
  }

  // Busca dados de um usuário específico pelo ID
  Future<AdminUser> getSingleUser(String userId, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    // ... (lógica de tratamento de sucesso/erro) ...
    if (response.statusCode == 200) {
      return AdminUser.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Falha ao carregar dados do usuário.');
    }
  }

  // Cria um novo usuário da clínica (médico, secretária)
  Future<http.Response> createClinicUser(Map<String, dynamic> userData, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/");
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(userData),
    );
  }

   // Atualiza dados de um usuário (nome, email, tipo, status)
  Future<http.Response> updateUser(String userId, Map<String, dynamic> data, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");
    return await http.patch( // PATCH para atualização parcial
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
    );
  }

  // Ativa/desativa um usuário
  Future<http.Response> updateUserStatus(String userId, bool isActive, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");
    return await http.patch( // PATCH para mudar apenas 'is_active'
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'is_active': isActive}),
    );
  }

  // Deleta um usuário
  Future<http.Response> deleteUser(String userId, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");
    return await http.delete( // Usa DELETE
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  // --- MÉTODO PARA BUSCAR CEP (ViaCEP) ---
   Future<Address?> fetchAddressFromCep(String cep) async {
    final cleanedCep = cep.replaceAll(RegExp(r'\D'), ''); // Remove não-dígitos
    if (cleanedCep.length != 8) return null; // Valida tamanho

    final url = Uri.parse('https://viacep.com.br/ws/$cleanedCep/json/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('erro') && data['erro'] == true) { // ViaCEP retorna 'erro: true' para CEP inválido
             debugPrint('ViaCEP retornou erro para o CEP: $cleanedCep');
             return null;
        }
        return Address.fromJson(data); // Usa o factory do modelo Address
      } else {
        debugPrint('Erro ViaCEP (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Erro ao buscar CEP: $e');
      return null;
    }
  }


} // --- FIM DA CLASSE ApiService ---


// --- Modelo Address (pode ficar aqui ou em models/address_model.dart) ---
class Address {
  final String cep;
  final String logradouro; // Rua/Avenida
  final String complemento;
  final String bairro;
  final String localidade; // Cidade
  final String uf; // Estado

  Address({
    required this.cep,
    required this.logradouro,
    required this.complemento,
    required this.bairro,
    required this.localidade,
    required this.uf,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      cep: json['cep'] ?? '',
      logradouro: json['logradouro'] ?? '',
      complemento: json['complemento'] ?? '',
      bairro: json['bairro'] ?? '',
      localidade: json['localidade'] ?? '',
      uf: json['uf'] ?? '',
    );
  }
}