// ARQUIVO: lib/views/pages/nova_consulta_page.dart (VERSÃO COM LÓGICA DE CARREGAMENTO CORRIGIDA)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart';
import 'package:medlink/services/api_service.dart';
// Importa o modelo Doctor que é usado nesta página
import 'package:medlink/models/doctor_model.dart';

class NovaConsultaPage extends StatefulWidget {
  final bool isRescheduling;
  final ProximaConsulta? consultaAntiga;

  const NovaConsultaPage({
    super.key,
    this.isRescheduling = false,
    this.consultaAntiga,
  });

  @override
  State<NovaConsultaPage> createState() => _NovaConsultaPageState();
}

class _NovaConsultaPageState extends State<NovaConsultaPage> {
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  bool _isLoadingData = true; // Loading inicial (especialidades)
  bool _isMedicoLoading = false; // Loading do dropdown de médicos
  String? _dataErrorMessage;

  // Lista de especialidades (vem como Map da API)
  List<Map<String, dynamic>> _listaEspecialidades = [];
  // Lista de médicos (agora começa vazia)
  List<Doctor> _listaMedicosFiltrada = [];

  String? selectedEspecialidadeLabel; // O 'label' (ex: "Cardiologia")
  String? selectedEspecialidadeKey; // O 'value' (ex: "CARDIOLOGIA")
  int? selectedMedicoId;

  DateTime? selectedDate;
  String? selectedHorario;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'pt_BR';
    _carregarDadosDosDropdowns();
  }

  // --- FUNÇÃO MODIFICADA ---
  Future<void> _carregarDadosDosDropdowns() async {
    setState(() {
      _isLoadingData = true; // Começa o loading principal
      _dataErrorMessage = null;
    });

    try {
      final accessToken = _apiService.getToken();
      if (accessToken == null) {
        throw Exception('Token não encontrado. Faça login novamente.');
      }

      // 1. Carrega APENAS as especialidades
      _listaEspecialidades = List<Map<String, dynamic>>.from(
        await _apiService.getEspecialidades(),
      );

      // 2. Lógica de reagendamento (se aplicável)
      if (widget.isRescheduling && widget.consultaAntiga != null) {
        final especialidadeAntigaLabel = widget.consultaAntiga!.especialidade;
        final medicoAntigoNome = widget.consultaAntiga!.medico;

        // Encontra a especialidade antiga na lista
        final especialidade = _listaEspecialidades.firstWhere(
          (e) => e['label'] == especialidadeAntigaLabel,
          orElse: () => {'key': '', 'label': ''},
        );

        selectedEspecialidadeLabel = especialidade['label'];
        selectedEspecialidadeKey = especialidade['key'];

        // 3. Se encontrou a especialidade, CARREGA OS MÉDICOS dela
        if (selectedEspecialidadeKey != null &&
            selectedEspecialidadeKey!.isNotEmpty) {
          
          // Chama a nova função para carregar os médicos filtrados
          await _carregarMedicosPorEspecialidade(selectedEspecialidadeKey!);

          // 4. Tenta pré-selecionar o médico antigo
          final medico = _listaMedicosFiltrada.firstWhere(
              (m) => m.fullName == medicoAntigoNome,
              orElse: () => _listaMedicosFiltrada.isNotEmpty
                  ? _listaMedicosFiltrada.first
                  : Doctor(id: 0, fullName: '', specialty: ''));
          selectedMedicoId = medico.id;
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
      if (mounted) {
        setState(() {
          _dataErrorMessage = "Erro ao carregar dados. Tente novamente.";
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingData = false; // Termina o loading principal
      });
    }
  }

  // --- NOVA FUNÇÃO ADICIONADA ---
  /// Busca na API os médicos para a especialidade selecionada.
  Future<void> _carregarMedicosPorEspecialidade(String especialidadeKey) async {
    setState(() {
      _isMedicoLoading = true; // Ativa o loading do dropdown de médico
      _listaMedicosFiltrada = []; // Limpa a lista antiga
      selectedMedicoId = null; // Limpa o médico selecionado
    });
    try {
      // Chama a NOVA função da API
      _listaMedicosFiltrada =
          await _apiService.getDoctorsByEspecialidade(especialidadeKey);
    } catch (e) {
      debugPrint("Erro ao carregar médicos: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erro ao carregar médicos."),
              backgroundColor: Colors.red),
        );
      }
    }
    setState(() {
      _isMedicoLoading = false; // Desativa o loading do médico
    });
  }

  // --- FUNÇÃO MODIFICADA ---
  void _onEspecialidadeChanged(String? novaEspecialidadeLabel) {
    if (novaEspecialidadeLabel == null) return;

    final especialidade = _listaEspecialidades.firstWhere(
      (e) => e['label'] == novaEspecialidadeLabel,
      // Corrigido para usar 'value' no orElse também
      orElse: () => {'value': '', 'label': ''}, 
    );

    // Corrigido para ler 'value' em vez de 'key'
    final especialidadeKey = especialidade['value']; // <-- CORREÇÃO AQUI

    setState(() {
      selectedEspecialidadeLabel = novaEspecialidadeLabel;
      selectedEspecialidadeKey = especialidadeKey;

      // Limpa a seleção de médico e a lista
      selectedMedicoId = null;
      _listaMedicosFiltrada = [];
    });

    // CHAMA A API para buscar os médicos filtrados
    if (especialidadeKey != null && especialidadeKey.isNotEmpty) {
      _carregarMedicosPorEspecialidade(especialidadeKey);
    }
  }

  List<String> gerarHorarios() {
    List<String> horarios = [];
    TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 30);
    TimeOfDay atual = start;
    while (atual.hour < end.hour ||
        (atual.hour == end.hour && atual.minute <= end.minute)) {
      if (atual.hour < 12 || atual.hour > 13) {
        String hora = atual.hour.toString().padLeft(2, '0');
        String minuto = atual.minute.toString().padLeft(2, '0');
        horarios.add('$hora:$minuto');
      }
      int novaHora = atual.hour;
      int novoMinuto = atual.minute + 30;
      if (novoMinuto >= 60) {
        novaHora++;
        novoMinuto -= 60;
      }
      atual = TimeOfDay(hour: novaHora, minute: novoMinuto);
    }
    return horarios;
  }

  void _abrirSeletorDeHorario(BuildContext context) {
    final List<String> horariosDisponiveis = gerarHorarios();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecione um horário',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.maxFinite,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: horariosDisponiveis.map((horario) {
                      final bool selecionado = selectedHorario == horario;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedHorario = horario;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selecionado
                                ? const Color(0xFF317714)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selecionado
                                  ? const Color(0xFF317714)
                                  : Colors.grey.shade400,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            horario,
                            style: TextStyle(
                              color:
                                  selecionado ? Colors.white : Colors.black87,
                              fontWeight: selecionado
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _salvarNovaConsulta() async {
    if (!mounted) return;

    if (selectedEspecialidadeKey == null ||
        selectedMedicoId == null ||
        selectedDate == null ||
        selectedHorario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final parts = selectedHorario!.split(':');
      final novaDataHora = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      bool success;
      if (widget.isRescheduling) {
        success = await _apiService.remarcarConsultaPaciente(
          widget.consultaAntiga!.id,
          novaDataHora,
        );
      } else {
        success = await _apiService.pacienteMarcarConsulta(
          selectedMedicoId!, // 1. O ID do médico (int)
          selectedEspecialidadeKey!, // 2. A Key da especialidade (String)
          novaDataHora, // 3. A data
        );
      }

      if (!mounted) return;

      if (success) {
        final successMessage = widget.isRescheduling
            ? 'Consulta reagendada com sucesso!'
            : 'Consulta marcada com sucesso!';

        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Sucesso!'),
              content: Text(successMessage),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Fecha o dialog
                  },
                ),
              ],
            );
          },
        );

        Navigator.pop(context);
      } else {
        throw Exception(
          widget.isRescheduling ? 'Falha ao remarcar' : 'Falha ao marcar',
        );
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = "Erro desconhecido. Tente novamente.";
      if (e.toString().toLowerCase().contains('falha ao marcar')) {
        errorMessage =
            "Ocorreu um erro no servidor (Erro 500). Verifique o backend.";
      } else if (e.toString().contains(":")) {
        errorMessage = e.toString().split(":").last.trim();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5BBCDC),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            Center(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isRescheduling
                              ? 'Reagendar Consulta'
                              : 'Nova Consulta',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.isRescheduling &&
                            widget.consultaAntiga != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Consulta original: ${DateFormat("dd/MM/yyyy 'às' HH:mm", "pt_BR").format(widget.consultaAntiga!.data)}',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_isLoadingData)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                    color: Color(0xFF317714)),
                                SizedBox(height: 10),
                                Text("Carregando dados..."),
                              ],
                            ),
                          )
                        else if (_dataErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 30),
                                const SizedBox(height: 10),
                                Text(
                                  _dataErrorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                    onPressed: _carregarDadosDosDropdowns,
                                    child: const Text("Tentar Novamente"))
                              ],
                            ),
                          )
                        else ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Especialidade',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: selectedEspecialidadeLabel,
                            items: _listaEspecialidades
                                .map((e) => DropdownMenuItem(
                                    value: e['label']
                                        as String, // Usa o 'label'
                                    child: Text(e['label'] as String)))
                                .toList(),
                            onChanged: _onEspecialidadeChanged,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Médico',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // --- CAMPO DE MÉDICO MODIFICADO ---
                          if (_isMedicoLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF317714))),
                            )
                          else
                            DropdownButtonFormField<int>(
                              value: selectedMedicoId,
                              items: _listaMedicosFiltrada
                                  .map((m) => DropdownMenuItem(
                                      value: m.id, // Usa o 'id' (int)
                                      child: Text(
                                          m.fullName) // Usa o 'fullName'
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedMedicoId = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: selectedEspecialidadeLabel == null
                                    ? 'Selecione uma especialidade primeiro'
                                    : (_listaMedicosFiltrada.isEmpty
                                        ? 'Nenhum médico encontrado'
                                        : 'Selecione o médico'),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                            ),
                          // --- FIM DA MODIFICAÇÃO ---

                          const SizedBox(height: 15),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Nova Data da Consulta',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 5),
                          GestureDetector(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                selectedDate != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(selectedDate!)
                                    : 'Selecione a data',
                                style: TextStyle(
                                  color: selectedDate != null
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Novo Horário da Consulta',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 5),
                          GestureDetector(
                            onTap: () => _abrirSeletorDeHorario(context),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                selectedHorario ?? 'Selecione o horário',
                                style: TextStyle(
                                  color: selectedHorario != null
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                        },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.grey),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _isSaving ? null : _salvarNovaConsulta,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF317714),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ))
                                      : const Text('Salvar'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}