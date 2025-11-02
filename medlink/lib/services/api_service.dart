
// ARQUIVO: lib/services/api_service.dart (VERSÃO CORRIGIDA COMPLETA)

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
      : "http://10.0.2.2:8000"; // Para Emulador Android

  static String? _accessToken; // Token JWT salvo após o login

  // --- GETTER PÚBLICO PARA O TOKEN ---
  String? getToken() {
    return _accessToken;
  }

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

  Future<bool> register(User user) async {
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
    return response.statusCode == 201;
  }

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
      return DashboardData.fromJson(data);
    } else {
      debugPrint('Falha no Dashboard Paciente: ${response.statusCode} | ${response.body}');
      throw Exception('Falha ao carregar dados do dashboard do paciente');
    }
  }

  Future<Map<String, dynamic>> getPacienteProfile() async {
    final url = Uri.parse("$baseUrl/api/pacientes/profile/"); 
    if (_accessToken == null) throw Exception('Token de acesso não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken", 
      },
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Falha ao carregar perfil: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updatePacienteProfile(Map<String, dynamic> profileData) async {
    final url = Uri.parse("$baseUrl/api/pacientes/profile/");
    if (_accessToken == null) throw Exception('Token de acesso não encontrado.');

    final response = await http.patch( 
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode(profileData), 
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      debugPrint('Erro ao atualizar perfil (${response.statusCode}): ${response.body}');
      throw Exception('Falha ao atualizar perfil');
    }
  }

  Future<List<ProximaConsulta>> getPacienteConsultasPendentes() async {
    final dashboardData = await fetchDashboardData();
    
    // CORREÇÃO: Adicionado 'reagendada'
    return dashboardData.todasConsultas.where((c) {
      final statusLower = c.status.toLowerCase();
      bool isValida = (statusLower == 'pendente' || 
                         statusLower == 'confirmada' ||
                         statusLower == 'reagendada');
      bool isFutura = c.data.isAfter(DateTime.now());
      return isValida && isFutura;
    }).toList();
  }

  Future<bool> remarcarConsultaPaciente(int consultaId, DateTime novaDataHora) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$consultaId/paciente-remarcar/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode({
        'data_hora': novaDataHora.toIso8601String(),
      }),
    );
    
    return response.statusCode == 200;
  }

  Future<bool> pacienteMarcarConsulta(int medicoId, String especialidadeNome, DateTime dataHora) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/paciente-marcar/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode({
        'medico_id': medicoId, 
        'especialidade_nome': especialidadeNome, 
        'data_hora': dataHora.toIso8601String(),
      }),
    );
    
    return response.statusCode == 201;
  }

  // --- ESTA É A VERSÃO CORRETA PARA ESTE ARQUIVO ---
  Future<bool> pacienteCancelarConsulta(int consultaId) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$consultaId/paciente-cancelar/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.post( 
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );
    
    if (response.statusCode == 200) {
      return true;
    } else {
      try {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        final errorMessage = responseBody['error'] ?? 'Erro desconhecido do servidor.';
        throw Exception(errorMessage); 
      } catch (e) {
        throw Exception('Falha ao cancelar. Status: ${response.statusCode}');
      }
    }
  }
  // --- FIM DA FUNÇÃO CORRIGIDA ---

  // --- ESTA É A FUNÇÃO QUE FALTAVA ---
  // Busca lista de pacientes (usado pela secretária e admin)
  Future<List<Patient>> getPatients(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/pacientes/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => Patient.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar pacientes (Status: ${response.statusCode})');
    }
  }
  // --- FIM DA FUNÇÃO QUE FALTAVA ---

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

  // --- MÉTODOS PARA MÉDICOS ---

  Future<List<Paciente>> getPacientesDoDia() async {
    final url = Uri.parse("$baseUrl/api/pacientes/hoje/"); 
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
      return body.map((e) => Paciente.fromJson(e)).toList();
    } else {
      throw Exception('Falha ao carregar pacientes do dia: ${response.statusCode}');
    }
  }

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

  Future<List<dynamic>> getEspecialidades() async {
    final url = Uri.parse("$baseUrl/api/medicos/especialidades/");
    if (_accessToken == null) throw Exception('Token não encontrado.');
    
    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Falha ao buscar especialidades');
    }
  }

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
      return body.map((key, value) => MapEntry(key, value as List<dynamic>));
    } else {
      throw Exception('Falha ao carregar a agenda: ${response.statusCode}');
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
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => Doctor.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar médicos (Status: ${response.statusCode})');
    }
  }
  
  Future<List<Doctor>> getDoctorsByEspecialidade(String especialidadeKey) async {
    final url = Uri.parse("$baseUrl/api/medicos/?especialidade=$especialidadeKey");
    
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken", 
      },
    );

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => Doctor.fromJson(json)).toList(); 
    } else {
      debugPrint('Falha ao carregar médicos filtrados: ${response.statusCode} | ${response.body}');
      throw Exception('Falha ao carregar médicos (Status: ${response.statusCode})');
    }
  }
  
  // --- MÉTODOS PARA CONSULTAS / AGENDAMENTOS ---

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
    if (response.statusCode == 404) {
      return ""; 
    }
    throw Exception('Falha ao carregar anotação.'); 
  }

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

  Future<http.Response> createAppointment(Appointment appointment, String accessToken) async {
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

  Future<List<Appointment>> getAppointments(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/dashboard/consultas-hoje/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == "[]") return [];
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => Appointment.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar agendamentos (Status: ${response.statusCode})');
    }
  }

  Future<http.Response> confirmAppointment(int appointmentId, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/consultas/$appointmentId/confirmar/");
    return await http.patch( 
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  Future<http.Response> cancelAppointment(int appointmentId, String reason, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/consultas/$appointmentId/cancelar/");
    return await http.patch( 
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'motivo': reason}), 
    );
  }

  Future<http.Response> updateAppointment(int appointmentId, DateTime newDateTime, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/$appointmentId/");
    return await http.put( 
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'data_hora': newDateTime.toIso8601String()}), 
    );
  }

  // --- MÉTODOS PARA SECRETÁRIA (Dashboard) ---

  Future<DashboardStats> getDashboardStats(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/secretarias/dashboard/stats/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
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

  Future<List<AdminUser>> getClinicUsers(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/");
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => AdminUser.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar usuários (Status: ${response.statusCode})');
    }
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

  Future<http.Response> updateUser(String userId, Map<String, dynamic> data, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");
    return await http.patch( 
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
    );
  }

  Future<http.Response> updateUserStatus(String userId, bool isActive, String accessToken) async {
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

  // --- MÉTODO PARA BUSCAR CEP (ViaCEP) ---
  Future<Address?> fetchAddressFromCep(String cep) async {
    final cleanedCep = cep.replaceAll(RegExp(r'\D'), ''); 
    if (cleanedCep.length != 8) return null; 

    final url = Uri.parse('https://viacep.com.br/ws/$cleanedCep/json/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('erro') && data['erro'] == true) { 
          debugPrint('ViaCEP retornou erro para o CEP: $cleanedCep');
          return null;
        }
        return Address.fromJson(data); 
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

// --- Modelo Address ---
class Address {
  final String cep;
  final String logradouro; 
  final String complemento;
  final String bairro;
  final String localidade; 
  final String uf; 

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