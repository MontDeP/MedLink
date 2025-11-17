import 'dart:convert';
import 'package:flutter/foundation.dart'; // Importado para usar debugPrint
import 'dart:io' show Platform;
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
import '../models/clinica_model.dart';
import '../models/address_model.dart';
import 'package:intl/intl.dart';
class ApiService {
  late final String baseUrl; 

  ApiService() {
    baseUrl = _getBaseUrl();
  }

  String _getBaseUrl() {
    if (kIsWeb) {
      // Se for Web
      return "http://127.0.0.1:8000";
    }

    try {
      if (Platform.isAndroid) {
        // Se for Emulador Android
        return "http://10.0.2.2:8000";
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isIOS) {
        // Se for Desktop (Windows, etc) ou Simulador iOS
        return "http://127.0.0.1:8000";
      } else {
        // Fallback
        return "http://127.0.0.1:8000"; 
      }
    } catch (e) {
      // Se houver erro na deteção
      return "http://127.0.0.1:8000";
    }
  }
  // --- FIM DA CORREÇÃO DA BASEURL ---

  static String? _accessToken; // Token JWT salvo após o login

  // --- MÉTODOS DE AUTENTICAÇÃO ---

  Future<Map<String, dynamic>?> login(String cpf, String password) async {
    final url = Uri.parse("$baseUrl/api/token/"); // Endpoint de login JWT
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "cpf": cpf,
          "password": password,
        }), // Envia CPF e senha
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
      return {
        'success': false,
        'error': e.toString(),
      }; // Retorna falha de conexão/geral
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

  // --- MÉTODOS DE RECUPERAÇÃO DE SENHA (versão única e correta) ---

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
        return {
          'success': false,
          'message': errorData['error'] ?? 'Link inválido ou expirado',
        };
      }
    } catch (e) {
      debugPrint('Erro de conexão em createPasswordConfirm: $e');
      return {
        'success': false,
        'message': 'Não foi possível conectar ao servidor.',
      };
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
      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return DashboardData.fromJson(data); // Usa o factory do modelo
    } else {
      debugPrint(
        'Falha no Dashboard Paciente: ${response.statusCode} | ${response.body}',
      );
      throw Exception('Falha ao carregar dados do dashboard do paciente');
    }
  }

  // Busca o perfil completo do paciente logado
  Future<Map<String, dynamic>> getPacienteProfile() async {
    final url = Uri.parse(
      "$baseUrl/api/pacientes/profile/",
    ); // Endpoint do perfil
    if (_accessToken == null)
      throw Exception('Token de acesso não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken", // Envia o token
      },
    );

    if (response.statusCode == 200) {
      return json.decode(
        utf8.decode(response.bodyBytes),
      ); // Retorna o JSON do perfil
    } else {
      throw Exception('Falha ao carregar perfil: ${response.statusCode}');
    }
  }

  // Atualiza o perfil do paciente logado
  Future<Map<String, dynamic>> updatePacienteProfile(
    Map<String, dynamic> profileData,
  ) async {
    final url = Uri.parse("$baseUrl/api/pacientes/profile/");
    if (_accessToken == null)
      throw Exception('Token de acesso não encontrado.');

    final response = await http.patch(
      // Usa PATCH para atualização parcial
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode(profileData), // Envia os dados a serem atualizados
    );

    if (response.statusCode == 200) {
      return json.decode(
        utf8.decode(response.bodyBytes),
      ); // Retorna o perfil atualizado
    } else {
      debugPrint(
        'Erro ao atualizar perfil (${response.statusCode}): ${response.body}',
      );
      throw Exception('Falha ao atualizar perfil');
    }
  }

  Future<List<ProximaConsulta>> getPacienteConsultasPendentes() async {
    // 1. Chama o endpoint do dashboard que JÁ FUNCIONA
    final dashboardData = await fetchDashboardData();

    // 2. Filtra a lista 'todasConsultas'
    return dashboardData.todasConsultas.where((c) {
      bool isPendenteOuConfirmada =
          (c.status.toLowerCase() == 'pendente' ||
          c.status.toLowerCase() == 'confirmada');
      // Usamos c.data (do ProximaConsulta) ao invés de c.horario
      bool isFutura = c.data.isAfter(DateTime.now());
      return isPendenteOuConfirmada && isFutura;
    }).toList();
  }

  // +++ INÍCIO DOS NOVOS MÉTODOS +++

  /// Busca a lista de todas as clínicas para o paciente selecionar.
  // +++ INÍCIO DOS NOVOS MÉTODOS DE AGENDAMENTO +++
  
  Future<List<Clinica>> getClinicasParaAgendamento() async {
    final url = Uri.parse("$baseUrl/api/clinicas/"); 
    if (_accessToken == null) throw Exception('Token não encontrado.');
    debugPrint("A chamar API: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
        "Accept": "application/json" // <-- Força o Django a enviar JSON
      },
    );

    if (response.statusCode == 200) {
      debugPrint("Resposta da API: ${response.body}");
      final dynamic decodedBody = json.decode(utf8.decode(response.bodyBytes));
      
      // O seu log do Django mostrou que /api/clinicas/ é paginada
      if (decodedBody is Map && decodedBody.containsKey('results')) {
          final List<dynamic> data = decodedBody['results'];
           return data.map((json) => Clinica.fromJson(json)).toList();
      } else if (decodedBody is List) {
           return decodedBody.map((json) => Clinica.fromJson(json)).toList();
      } else {
          // Este é o erro que você estava a ter
          throw Exception('Formato de resposta inesperado para clínicas');
      }
    } else {
      debugPrint('Falha ao buscar clínicas: ${response.statusCode} | ${response.body}');
      throw Exception('Falha ao carregar clínicas');
    }
  }

  Future<List<String>> getEspecialidadesPorClinica(int clinicaId) async {
    final url = Uri.parse("$baseUrl/api/clinicas/$clinicaId/especialidades/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
        "Accept": "application/json" // <-- Força o Django a enviar JSON
      },
    );

    if (response.statusCode == 200) {
      final dynamic decodedBody = json.decode(utf8.decode(response.bodyBytes));
      if (decodedBody is List) {
        return decodedBody.cast<String>();
      } else {
        return []; 
      }
    } else {
      debugPrint('Falha ao buscar especialidades: ${response.statusCode} | ${response.body}');
      throw Exception('Falha ao carregar especialidades da clínica');
    }
  }

  Future<List<Doctor>> getMedicosPorClinicaEEspecialidade(int clinicaId, String especialidade) async {
    final url = Uri.parse("$baseUrl/api/medicos/buscar/?clinica_id=$clinicaId&especialidade=$especialidade");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
        "Accept": "application/json" // <-- Força o Django a enviar JSON
      },
    );

    if (response.statusCode == 200) {
      final dynamic decodedBody = json.decode(utf8.decode(response.bodyBytes));
      if (decodedBody is List) {
        return decodedBody.map((json) => Doctor.fromJson(json)).toList();
      } else {
        return [];
      }
    } else {
      debugPrint('Falha ao buscar médicos: ${response.statusCode} | ${response.body}');
      throw Exception('Falha ao carregar médicos');
    }
  }
  // +++ FIM DOS NOVOS MÉTODOS ++++

  /// Permite ao paciente remarcar uma consulta existente.
  /// (Este método estava correto e é mantido)
  Future<bool> remarcarConsultaPaciente(
    int consultaId,
    DateTime novaDataHora,
  ) async {
    // ATENÇÃO: Você precisará criar este endpoint no seu backend!
    final url = Uri.parse(
      "$baseUrl/api/agendamentos/$consultaId/paciente-remarcar/",
    );
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
      body: jsonEncode({'data_hora': novaDataHora.toIso8601String()}),
    );

    // Sucesso se for 200 OK
    return response.statusCode == 200;
  }

  Future<bool> cancelarConsultaPaciente(int consultaId) async {
    // Chama o novo endpoint que criamos
    final url = Uri.parse(
      "$baseUrl/api/agendamentos/$consultaId/paciente-cancelar/",
    );
    if (_accessToken == null) throw Exception('Token não encontrado.');

    // Usamos PATCH (sem corpo) apenas para acionar a ação no backend
    final response = await http.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    // Sucesso se for 200 OK (pois retorna a consulta atualizada)
    return response.statusCode == 200;
  }

  // +++ MÉTODO 'pacienteMarcarConsulta' CORRIGIDO +++
  Future<bool> pacienteMarcarConsulta(
    int clinicaId, // <--- CORRIGIDO
    int medicoId,   // <--- CORRIGIDO
    DateTime dataHora,
  ) async {
    final url = Uri.parse("$baseUrl/api/agendamentos/paciente-marcar/");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
        "Accept": "application/json" // <-- Força o Django a enviar JSON
      },
      body: jsonEncode({
        'clinica_id': clinicaId, // <--- CORRIGIDO
        'medico_id': medicoId,   // <--- CORRIGIDO
        'data_hora': dataHora.toIso8601String(),
      }),
    );

    return response.statusCode == 201; // Sucesso é 201 Created
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

  // Cria um novo paciente (usado pela secretária)
  Future<http.Response> createPatient(
    Map<String, dynamic> patientData,
    String accessToken,
  ) async {
    final url = Uri.parse(
      "$baseUrl/api/pacientes/register/",
    ); // Reutiliza endpoint de registro
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer $accessToken', // Secretária precisa estar autenticada
      },
      body: jsonEncode(patientData),
    );
  }

  // --- MÉTODOS PARA MÉDICOS ---

  // Busca pacientes agendados para o médico logado HOJE
  Future<List<Paciente>> getPacientesDoDia() async {
    final url = Uri.parse(
      "$baseUrl/api/pacientes/hoje/",
    ); // Endpoint específico
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
      throw Exception(
        'Falha ao carregar pacientes do dia: ${response.statusCode}',
      );
    }
  }

  // Busca o histórico de consultas de um paciente específico PARA o médico logado
  Future<List<consultas_model.Consulta>> getHistoricoConsultas(
    int pacienteId,
  ) async {
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
      return body
          .map((json) => consultas_model.Consulta.fromJson(json))
          .toList();
    } else {
      throw Exception('Falha ao carregar o histórico: ${response.statusCode}');
    }
  }

  // Busca a agenda do médico logado para um mês/ano específico
  Future<Map<String, List<dynamic>>> getMedicoAgenda(
    int year,
    int month,
  ) async {
    final url = Uri.parse(
      "$baseUrl/api/medicos/agenda/?year=$year&month=$month",
    );
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      // A API retorna chave como "YYYY-MM-DD", o front trata
      return body.map((key, value) => MapEntry(key, value as List<dynamic>));
    } else {
      throw Exception('Falha ao carregar a agenda: ${response.statusCode}');
    }
  }

  Future<List<String>> getHorariosOcupados(int medicoId, DateTime data) async {
    // Formata a data para YYYY-MM-DD, que é o que o Django espera
    final String dataStr = DateFormat('yyyy-MM-dd').format(data);
    
    final url = Uri.parse("$baseUrl/api/medicos/$medicoId/horarios-ocupados/?data=$dataStr");
    if (_accessToken == null) throw Exception('Token não encontrado.');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_accessToken",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
      return body.cast<String>(); // Retorna a Lista de horários em ISO String
    } else {
      debugPrint('Falha ao buscar horários: ${response.statusCode} | ${response.body}');
      throw Exception('Falha ao carregar horários do médico');
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

    final response = await http.post(
      // Endpoint usa POST para criar/atualizar
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

    final response = await http.post(
      // Endpoint de finalização
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
      body: jsonEncode(
        appointment.toJson(),
      ), // Usa o toJson do modelo Appointment
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

  // Confirma um agendamento (secretária)
  Future<http.Response> confirmAppointment(
    int appointmentId,
    String accessToken,
  ) async {
    final url = Uri.parse(
      "$baseUrl/api/secretarias/consultas/$appointmentId/confirmar/",
    );
    return await http.patch(
      // Usa PATCH para mudar o status
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  // Cancela um agendamento (secretária)
  Future<http.Response> cancelAppointment(
    int appointmentId,
    String reason,
    String accessToken,
  ) async {
    final url = Uri.parse(
      "$baseUrl/api/secretarias/consultas/$appointmentId/cancelar/",
    );
    return await http.patch(
      // Usa PATCH
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'motivo': reason}), // Envia o motivo
    );
  }

  // Atualiza (remarca) um agendamento (secretária)
  Future<http.Response> updateAppointment(
    int appointmentId,
    DateTime newDateTime,
    String accessToken,
  ) async {
    // Atenção: O endpoint correto pode ser /api/agendamentos/<id>/ ou um específico da secretária
    final url = Uri.parse("$baseUrl/api/agendamentos/$appointmentId/");
    return await http.put(
      // Usamos PUT ou PATCH dependendo da API
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'data_hora': newDateTime.toIso8601String(),
      }), // Envia a nova data/hora
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

  // --- MÉTODOS PARA ADMIN ---

  // Busca todos os usuários da clínica (médicos, secretárias, etc.)
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

  // Atualiza dados de um usuário (nome, email, tipo, status)
  Future<http.Response> updateUser(
    String userId,
    Map<String, dynamic> data,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/admin/users/$userId/");

    // Normalização também no PATCH (+ fallback pelo token)
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

    return await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
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

  // Helper: decodifica o payload do JWT (mantenha UMA versão)
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Token JWT inválido');
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      return payloadMap;
    } catch (e) {
      debugPrint('Erro ao decodificar token: $e');
      return null;
    }
  }

  // --- NOVO MÉTODO: BUSCA ENDEREÇO POR CEP ---

  Future<Address?> fetchAddressFromCep(String cep) async {
    final cleanedCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanedCep.length != 8) return null;

    final url = Uri.parse('https://viacep.com.br/ws/$cleanedCep/json/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map && data['erro'] == true) {
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

  // --- SUPER ADMIN / ADMIN: Clínicas e Admins ---

  Future<List<Map<String, dynamic>>> getAllClinics(String accessToken) async {
    final urls = [
      Uri.parse("$baseUrl/api/admin/clinicas/"),
      Uri.parse("$baseUrl/api/clinicas/"),
    ];

    for (final url in urls) {
      final resp = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes);
        final decoded = json.decode(body);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
        if (decoded is Map && decoded['results'] is List) {
          return (decoded['results'] as List).cast<Map<String, dynamic>>();
        }
        return <Map<String, dynamic>>[];
      }
      if (resp.statusCode == 403 || resp.statusCode == 404) {
        // tenta o próximo endpoint
        continue;
      }
      // erro diferente de 403/404: falha direta se for o último
      if (url == urls.last) {
        throw Exception(
          'Falha ao listar clínicas (Status: ${resp.statusCode})',
        );
      }
    }
    throw Exception('Falha ao listar clínicas.');
  }

  Future<List<Map<String, dynamic>>> getAdmins(
    String accessToken, {
    String? search,
  }) async {
    final base = "$baseUrl/api/admin/users/?user_type=ADMIN";
    final url = Uri.parse(
      search == null || search.isEmpty
          ? base
          : "$base&search=${Uri.encodeQueryComponent(search)}",
    );
    final resp = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(resp.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        'Falha ao listar administradores (Status: ${resp.statusCode})',
      );
    }
  }

  Future<http.Response> assignClinicAdmin(
    int clinicId,
    Map<String, dynamic> payload,
    String accessToken,
  ) async {
    final url = Uri.parse(
      "$baseUrl/api/admin/clinicas/$clinicId/assign-admin/",
    );
    return await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    // Espera 200 em sucesso
  }

  // --- Referências do app de Clínicas ---

  Future<List<Map<String, dynamic>>> getEstados(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/clinicas/estados/");
    final resp = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(resp.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Falha ao carregar estados (${resp.statusCode})');
    }
  }

  Future<List<Map<String, dynamic>>> getCidades(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/clinicas/cidades/");
    final resp = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(resp.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Falha ao carregar cidades (${resp.statusCode})');
    }
  }

  Future<List<Map<String, dynamic>>> getTiposClinica(String accessToken) async {
    final url = Uri.parse("$baseUrl/api/clinicas/tipos-clinica/");
    final resp = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(resp.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        'Falha ao carregar tipos de clínica (${resp.statusCode})',
      );
    }
  }

  Future<http.Response> createClinicOnly(
    Map<String, dynamic> clinicData,
    String accessToken,
  ) async {
    final url = Uri.parse("$baseUrl/api/clinicas/");
    return await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(clinicData),
    );
    // Espera 201/200
  }

  // --- Utilidade: nome da clínica por ID (usado no dashboard) ---

  Future<String?> getClinicName(int clinicaId, String accessToken) async {
    final url = Uri.parse("$baseUrl/api/clinicas/$clinicaId/");
    try {
      final resp = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        return data['nome_fantasia'] ?? data['nome'] ?? data['name'];
      } else {
        debugPrint('getClinicName falhou: ${resp.statusCode} ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Erro em getClinicName: $e');
      return null;
    }
  }
}

