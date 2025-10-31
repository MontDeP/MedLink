import 'dart:convert';
import 'package:flutter/foundation.dart'; // Importado para usar debugPrint
import 'package:http/http.dart' as http;

import 'package:medlink/views/pages/admin.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../models/dashboard_stats_model.dart';
import '../models/patient_model.dart';
import '../models/doctor_model.dart';
import '../models/paciente.dart';
import '../models/consultas.dart' as consultas_model;

class ApiService {
  // ✅ Base URL unificada
  final String baseUrl = kIsWeb
      ? "http://127.0.0.1:8000"
      : "http://10.0.2.2:8000";

  static String? _accessToken;

  Future<Map<String, dynamic>?> login(String cpf, String password) async {
    final url = Uri.parse("$baseUrl/api/token/");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cpf": cpf, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        final String? userType = _getUserTypeFromToken(_accessToken!);

        return {
          'success': true,
          'access_token': data['access'],
          'refresh_token': data['refresh'],
          'user_type': userType ?? 'unknown',
        };
      } else {
        return {
          'success': false,
          'status_code': response.statusCode,
          'body': response.body,
        };
      }
    } catch (e) {
      debugPrint('Erro na chamada de login: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ✅ Helper para extrair o tipo de usuário do token JWT
  String? _getUserTypeFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Token JWT inválido');
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      return payloadMap['user_type'];
    } catch (e) {
      debugPrint('Erro ao decodificar token: $e');
      return null;
    }
  }

  // ✅ REGISTRO DE PACIENTE
  Future<bool> register(User user) async {
    // separa o nome completo
    final parts = user.username.split(' ');
    final firstName = parts.isNotEmpty ? parts.first : user.username;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final response = await http.post(
      Uri.parse("$baseUrl/api/pacientes/register/"),
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

    debugPrint("Status: ${response.statusCode}");
    debugPrint("Body: ${response.body}");

    return response.statusCode == 201;
  }

  // ✅ PACIENTES DO DIA
  Future<List<Paciente>> getPacientesDoDia() async {
    final url = Uri.parse("$baseUrl/api/pacientes/hoje/");

    if (_accessToken == null) {
      throw Exception(
        'Token de acesso não encontrado. Faça o login novamente.',
      );
    }

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((e) => Paciente.fromJson(e)).toList();
    } else {
      throw Exception(
        'Falha ao carregar pacientes do dia: ${response.statusCode}',
      );
    }
  }

  // --- NOVO MÉTODO ADICIONADO AQUI ---
  Future<List<consultas_model.Consulta>> getHistoricoConsultas(
    int pacienteId,
  ) async {
    final url = Uri.parse("$baseUrl/api/pacientes/$pacienteId/historico/");

    if (_accessToken == null) {
      throw Exception('Token de acesso não encontrado.');
    }

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body
          .map((json) => consultas_model.Consulta.fromJson(json))
          .toList();
    } else {
      throw Exception('Falha ao carregar o histórico: ${response.statusCode}');
    }
  }

  // --- NOVOS MÉTODOS PARA ANOTAÇÕES ---

  // Busca a anotação de uma consulta específica
  Future<String?> getAnotacao(int consultaId) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$consultaId/anotacao/");
    if (_accessToken == null) return null;

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $_accessToken"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['conteudo'];
    }
    // Se a anotação não existir, a API retornará 404, o que é normal.
    if (response.statusCode == 404) {
      return ""; // Retorna string vazia se não houver anotação
    }
    throw Exception('Falha ao carregar anotação.');
  }

  // Salva ou atualiza a anotação de uma consulta
  Future<void> salvarAnotacao(int consultaId, String conteudo) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$consultaId/anotacao/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode({'conteudo': conteudo}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao salvar anotação.');
    }
  }

  Future<Map<String, List<dynamic>>> getMedicoAgenda(
    int year,
    int month,
  ) async {
    final url = Uri.parse(
      "$baseUrl/api/medicos/agenda/?year=$year&month=$month",
    );

    if (_accessToken == null) {
      throw Exception('Token de acesso não encontrado.');
    }

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      // O corpo da resposta é um mapa, então fazemos o decode diretamente
      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      // Convertemos as chaves de String para DateTime para usar no calendário
      return body.map((key, value) => MapEntry(key, value as List<dynamic>));
    } else {
      throw Exception('Falha ao carregar a agenda: ${response.statusCode}');
    }
  }

  // ✅ DASHBOARD STATS
  Future<DashboardStats> getDashboardStats(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/dashboard/stats/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "{}") {
        return DashboardStats(
          today: 0,
          confirmed: 0,
          pending: 0,
          totalMonth: 0,
        );
      }
      return DashboardStats.fromJson(
        json.decode(utf8.decode(response.bodyBytes)),
      );
    } else {
      throw Exception('Falha ao carregar estatísticas do dashboard.');
    }
  }

  // ✅ CONSULTAS / AGENDAMENTOS
  Future<List<Appointment>> getAppointments(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/dashboard/consultas-hoje/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return jsonList.map((json) => Appointment.fromJson(json)).toList();
    } else {
      throw Exception(
        'Falha ao carregar agendamentos (Status: ${response.statusCode})',
      );
    }
  }

  Future<http.Response> createAppointment(
    Appointment appointment,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/");
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(appointment.toJson()),
    );
  }
  // Em lib/services/api_service.dart

  // --- MÉTODOS DE AÇÃO PARA AGENDAMENTOS ---

  /// Envia uma requisição PATCH para confirmar uma consulta.
  Future<http.Response> confirmAppointment(
    int appointmentId,
    String accessToken,
  ) async {
    final url = Uri.parse(
      "$baseUrl/api/secretarias/consultas/$appointmentId/confirmar/",
    );
    return await http.patch(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  /// Envia uma requisição PATCH para cancelar uma consulta, enviando um motivo.
  Future<http.Response> cancelAppointment(
    int appointmentId,
    String reason,
    String accessToken,
  ) async {
    final url = Uri.parse(
      "$baseUrl/api/secretarias/consultas/$appointmentId/cancelar/",
    );
    return await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'motivo': reason}),
    );
  }

  /// Envia uma requisição PUT/PATCH para atualizar (remarcar) uma consulta.
  Future<http.Response> updateAppointment(
    int appointmentId,
    DateTime newDateTime,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$appointmentId/");

    // Usando PATCH, que é mais adequado para atualizar apenas um campo (data_hora)
    return await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      // O backend espera o campo 'data_hora' no formato ISO 8601
      body: jsonEncode({'data_hora': newDateTime.toIso8601String()}),
    );
  }

  Future<bool> finalizarConsulta(int consultaId, String conteudo) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$consultaId/finalizar/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode({'conteudo': conteudo}),
    );

    return response.statusCode == 200;
  }

  // ✅ ADMIN (Usuários da Clínica)
  Future<List<AdminUser>> getClinicUsers(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/");

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return jsonList.map((json) => AdminUser.fromJson(json)).toList();
    } else {
      throw Exception(
        'Falha ao carregar usuários (Status: ${response.statusCode})',
      );
    }
  }

  Future<http.Response> updateUserStatus(
    String userId,
    bool isActive,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");
    return await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'is_active': isActive}),
    );
  }

  Future<http.Response> deleteUser(String userId, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");
    return await http.delete(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  Future<http.Response> createClinicUser(
    Map<String, dynamic> userData,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/admin/users/");

    // Normaliza o payload para compatibilidade com o backend
    final body = Map<String, dynamic>.from(userData);
    final rawType = (body['user_type'] ?? body['tipo'] ?? '').toString();
    final userType = rawType.toUpperCase();

    // Detecta clinicId nas várias chaves
    dynamic clinicIdRaw =
        body['clinica_id'] ??
        body['clinic_id'] ??
        body['clinicaId'] ??
        body['clinica'];

    // Fallback: usa clinica do token se não vier no body
    if (clinicIdRaw == null) {
      final payload = _decodeJwtPayload(accessToken);
      final tokenClinicId = payload?['clinica_id'] ?? payload?['clinicaId'];
      if (tokenClinicId != null) clinicIdRaw = tokenClinicId;
    }

    if (clinicIdRaw != null) {
      final clinicIdParsed =
          int.tryParse(clinicIdRaw.toString()) ?? clinicIdRaw;

      if (userType == 'MEDICO') {
        // Medico usa M2M "clinicas"
        body['clinicas'] = [clinicIdParsed];
        body.remove('clinica'); // evita conflito
      } else if (userType == 'SECRETARIA' ||
          userType == 'PACIENTE' ||
          userType == 'ADMIN') {
        // Demais perfis usam FK "clinica"
        body['clinica'] = clinicIdParsed;
        body.remove('clinicas'); // evita conflito
      }
      // Remove aliases para evitar kwargs inesperados no backend
      body.remove('clinica_id');
      body.remove('clinic_id');
      body.remove('clinicaId');
    }

    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
  }

  Future<AdminUser> getSingleUser(String userId, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return AdminUser.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Falha ao carregar dados do usuário.');
    }
  }

  Future<http.Response> updateUser(
    String userId,
    Map<String, dynamic> data,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/admin/users/$userId/");

    // --- Normalização também no PATCH (+ fallback pelo token) ---
    final body = Map<String, dynamic>.from(data);
    final rawType = (body['user_type'] ?? body['tipo'] ?? '').toString();
    final userType = rawType.toUpperCase();

    dynamic clinicIdRaw =
        body['clinica_id'] ??
        body['clinic_id'] ??
        body['clinicaId'] ??
        body['clinica'];

    if (clinicIdRaw == null) {
      final payload = _decodeJwtPayload(accessToken);
      final tokenClinicId = payload?['clinica_id'] ?? payload?['clinicaId'];
      if (tokenClinicId != null) clinicIdRaw = tokenClinicId;
    }

    if (clinicIdRaw != null) {
      final clinicIdParsed =
          int.tryParse(clinicIdRaw.toString()) ?? clinicIdRaw;

      if (userType == 'MEDICO') {
        body['clinicas'] = [clinicIdParsed];
        body.remove('clinica');
      } else {
        body['clinica'] = clinicIdParsed;
        body.remove('clinicas');
      }
      body.remove('clinica_id');
      body.remove('clinic_id');
      body.remove('clinicaId');
    }
    // --- fim normalização ---

    return await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
  }

  // ✅ PACIENTES e MÉDICOS
  Future<List<Patient>> getPatients(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/pacientes/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return jsonList.map((json) => Patient.fromJson(json)).toList();
    } else {
      throw Exception(
        'Falha ao carregar pacientes (Status: ${response.statusCode})',
      );
    }
  }

  Future<List<Doctor>> getDoctors(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/medicos/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return jsonList.map((json) => Doctor.fromJson(json)).toList();
    } else {
      throw Exception(
        'Falha ao carregar médicos (Status: ${response.statusCode})',
      );
    }
  }

  Future<http.Response> createPatient(
    Map<String, dynamic> patientData,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/pacientes/register/");
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(patientData),
    );
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    // Agora '$baseUrl' funciona porque está dentro da classe
    final url = Uri.parse('$baseUrl/api/users/request-password-reset/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        // O backend respondeu com sucesso
        return {'success': true, 'message': 'E-mail de recuperação enviado.'};
      } else {
        // Tenta decodificar a mensagem de erro do backend
        try {
          final responseBody = json.decode(utf8.decode(response.bodyBytes));
          // Assumindo que seu backend envia erros como {'error': '...'}
          return {
            'success': false,
            'message':
                responseBody['error'] ?? 'E-mail não encontrado ou inválido.',
          };
        } catch (e) {
          return {
            'success': false,
            'message':
                'Erro ao processar resposta do servidor. Status: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      debugPrint('Erro de conexão em requestPasswordReset: $e');
      return {
        'success': false,
        'message':
            'Não foi possível conectar ao servidor. Verifique sua internet.',
      };
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset(
    String uid,
    String token,
    String password,
  ) async {
    // Agora '$baseUrl' funciona porque está dentro da classe
    final url = Uri.parse('$baseUrl/api/users/reset-password-confirm/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': uid,
          'token': token,
          'password': password, // O backend espera 'password'
        }),
      );

      if (response.statusCode == 200) {
        // Sucesso
        return {'success': true, 'message': 'Senha redefinida com sucesso.'};
      } else {
        // Tenta decodificar a mensagem de erro do backend
        try {
          final responseBody = json.decode(utf8.decode(response.bodyBytes));
          // Pega a primeira mensagem de erro
          String errorMessage = "Token inválido ou expirado.";
          if (responseBody is Map) {
            // Ex: {'password': ['erro...']} ou {'detail': 'erro...'}
            final errors = responseBody.values.first;
            if (errors is List) {
              errorMessage = errors.first;
            } else {
              errorMessage = errors.toString();
            }
          }
          return {'success': false, 'message': errorMessage};
        } catch (e) {
          return {
            'success': false,
            'message': 'Erro no servidor. Status: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      debugPrint('Erro de conexão em confirmPasswordReset: $e');
      return {
        'success': false,
        'message': 'Não foi possível conectar ao servidor.',
      };
    }
  }

  Future<Map<String, dynamic>> createPasswordConfirm(
    String uid,
    String token,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/create-password-confirm/'),

      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'uid': uid,
        'token': token,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Senha definida com sucesso.'};
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': false,
        'message': errorData['error'] ?? 'Link inválido ou expirado',
      };
    }
  }

  Future<List<dynamic>> listarAgendamentosPorClinica(
    String token,
    int clinicaId,
  ) async {
    final url = Uri.parse('$baseUrl/agendamentos/?clinica=$clinicaId');
    final resp = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Erro ao listar agendamentos: ${resp.statusCode}');
    }
  }

  Future<dynamic> criarAgendamento(
    Map<String, dynamic> dados,
    String token,
    int clinicaId,
  ) async {
    final url = Uri.parse('$baseUrl/agendamentos/');
    final body = Map<String, dynamic>.from(dados);
    body['clinica'] = clinicaId;
    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return jsonDecode(resp.body);
    } else {
      throw Exception(
        'Erro ao criar agendamento: ${resp.statusCode} - ${resp.body}',
      );
    }
  }

  // --- NOVO MÉTODO: Buscar dados da clínica por ID e retornar o nome ---
  Future<String?> getClinicName(int clinicaId, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/clinicas/$clinicaId/");
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        // Ajuste o campo conforme sua API ('nome' ou 'name')
        return data['nome'] ?? data['name'] ?? null;
      } else {
        debugPrint(
          'getClinicName: resposta inválida ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Erro em getClinicName: $e');
      return null;
    }
  }

  // --- NOVO: Buscar pacientes filtrados por clínica ---
  Future<List<Patient>> getPatientsByClinic(
    int clinicaId,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/pacientes/?clinica=$clinicaId");
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return jsonList.map((json) => Patient.fromJson(json)).toList();
    } else {
      debugPrint(
        'getPatientsByClinic failed: ${response.statusCode} ${response.body}',
      );
      throw Exception('Falha ao carregar pacientes da clínica.');
    }
  }

  // --- NOVO: Buscar médicos filtrados por clínica ---
  Future<List<Doctor>> getDoctorsByClinic(
    int clinicaId,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/medicos/?clinica=$clinicaId");
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return jsonList.map((json) => Doctor.fromJson(json)).toList();
    } else {
      debugPrint(
        'getDoctorsByClinic failed: ${response.statusCode} ${response.body}',
      );
      throw Exception('Falha ao carregar médicos da clínica.');
    }
  }

  // Helper: decodifica o payload do JWT
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
