// lib/views/pages/nova_consulta_page.dart (VERSÃO CORRIGIDA COMPLETA)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart';

// --- IMPORTS ADICIONADOS ---
import 'package:medlink/services/api_service.dart';
import 'package:medlink/models/clinica_model.dart';
import 'package:medlink/models/doctor_model.dart'; // Importa o Doctor

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
  // CORREÇÃO: Instancia o ApiService com o construtor
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  // lib/views/pages/nova_consulta_page.dart
// Dentro da classe _NovaConsultaPageState

  // vvvv ADICIONE ESTA FUNÇÃO vvvv
  void _showHorarioOcupadoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Horário Indisponível'),
          content: const Text(
              'Este horário (ou um horário próximo) já está agendado para o médico selecionado.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Fecha o pop-up
              },
            ),
          ],
        );
      },
    );
  }
  // ^^^^ FIM DA NOVA FUNÇÃO ^^^^

  // --- ESTADOS PARA OS DROPDOWNS DINÂMICOS ---
  List<Clinica> _listaClinicas = [];
  Clinica? _selectedClinica;
  bool _isLoadingClinicas = false;

  List<String> _listaEspecialidades = [];
  String? _selectedEspecialidade;
  bool _isLoadingEspecialidades = false;

  List<Doctor> _listaMedicos = [];
  Doctor? _selectedMedico;
  bool _isLoadingMedicos = false;

  DateTime? _selectedDate;
  String? _selectedHorario;
  // --- FIM DOS ESTADOS ---

  // --- NOSSAS NOVAS ALTERAÇÕES ---
  bool _isLoadingHorarios = false;
  // Armazena os horários OCUPADOS (ex: "10:30", "11:00")
  Set<String> _horariosOcupados = {};
  // --- FIM DAS NOVAS ALTERAÇÕES ---

  @override
  void initState() {
    super.initState();
    // A lógica de reagendamento aqui precisará ser melhorada
    // para pré-selecionar os IDs corretos.
    if (!widget.isRescheduling) {
      _carregarClinicas();
    } else {
      _carregarClinicas();
    }
  }

  // --- LÓGICA DE CARREGAMENTO DE DADOS ---

  Future<void> _carregarClinicas() async {
    setState(() {
      _isLoadingClinicas = true;
      _listaClinicas = [];
      _selectedClinica = null;
    });
    try {
      // Chama a API
      final clinicas = await _apiService.getClinicasParaAgendamento();
      if (!mounted) return;
      setState(() {
        _listaClinicas = clinicas;
        _isLoadingClinicas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingClinicas = false);
      _showError('Erro ao carregar clínicas: $e');
    }
  }

  Future<void> _onClinicaSelected(Clinica? clinica) async {
    // Reseta os campos dependentes
    setState(() {
      _selectedClinica = clinica;
      _listaEspecialidades = [];
      _selectedEspecialidade = null;
      _listaMedicos = [];
      _selectedMedico = null;
      _isLoadingEspecialidades = true; // Ativa loading
    });

    if (clinica == null) {
      setState(() => _isLoadingEspecialidades = false);
      return;
    }

    try {
      final especialidades =
          await _apiService.getEspecialidadesPorClinica(clinica.id);
      if (!mounted) return;
      setState(() {
        _listaEspecialidades = especialidades;
        _isLoadingEspecialidades = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingEspecialidades = false);
      _showError('Erro ao carregar especialidades: $e');
    }
  }

  Future<void> _onEspecialidadeSelected(String? especialidade) async {
    // Reseta os campos dependentes
    setState(() {
      _selectedEspecialidade = especialidade;
      _listaMedicos = [];
      _selectedMedico = null;
      _isLoadingMedicos = true; // Ativa loading
    });

    if (especialidade == null || _selectedClinica == null) {
      setState(() => _isLoadingMedicos = false);
      return;
    }

    try {
      _listaMedicos = await _apiService.getMedicosPorClinicaEEspecialidade(
        _selectedClinica!.id,
        especialidade,
      );
      if (!mounted) return;
      setState(() {
        _isLoadingMedicos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMedicos = false);
      _showError('Erro ao carregar médicos: $e');
    }
  }

  // Helper para mostrar erros
  _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- LÓGICA DE SALVAR ATUALIZADA ---
  Future<void> _salvarNovaConsulta() async {
    if (_selectedClinica == null ||
        _selectedEspecialidade == null ||
        _selectedMedico == null ||
        _selectedDate == null ||
        _selectedHorario == null) {
      _showError('Por favor, preencha todos os campos.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final parts = _selectedHorario!.split(':');
      final novaDataHora = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
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
        // Chama a função correta com IDs
        success = await _apiService.pacienteMarcarConsulta(
          _selectedClinica!.id,
          _selectedMedico!.id,
          novaDataHora,
        );
      }

      if (!mounted) return;

      if (success) {
        final successMessage = widget.isRescheduling
            ? 'Consulta reagendada com sucesso!'
            : 'Consulta marcada com sucesso!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(
          widget.isRescheduling ? 'Falha ao remarcar' : 'Falha ao marcar',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Erro ao salvar: $e');
    } finally {
      setState(() => _isSaving = false);
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
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
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
                        const SizedBox(height: 20),

                        // --- 1. DROPDOWN DE CLÍNICA (DINÂMICO) ---
                        _buildDropdownHeader('Clínica'),
                        DropdownButtonFormField<Clinica>(
                          value: _selectedClinica,
                          hint: const Text('Selecione a clínica'),
                          isExpanded: true,
                          items: _isLoadingClinicas
                              ? [] // Mostra vazio enquanto carrega
                              : _listaClinicas
                                  .map((clinica) => DropdownMenuItem(
                                        value: clinica,
                                        child: Text(clinica.nomeFantasia,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                          onChanged: _isSaving ? null : _onClinicaSelected,
                          decoration: _buildDropdownDecoration(
                              isLoading: _isLoadingClinicas),
                        ),
                        const SizedBox(height: 15),

                        // --- 2. DROPDOWN DE ESPECIALIDADE (DINÂMICO) ---
                        _buildDropdownHeader('Especialidade'),
                        DropdownButtonFormField<String>(
                          value: _selectedEspecialidade,
                          hint: const Text('Selecione a especialidade'),
                          disabledHint:
                              const Text('Primeiro selecione a clínica'),
                          isExpanded: true,
                          items: _isLoadingEspecialidades
                              ? []
                              : _listaEspecialidades
                                  .map((especialidade) => DropdownMenuItem(
                                        value: especialidade,
                                        // TODO: Mapear para nome amigável
                                        child: Text(especialidade,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                          onChanged: _isSaving || _selectedClinica == null
                              ? null
                              : _onEspecialidadeSelected,
                          decoration: _buildDropdownDecoration(
                              isLoading: _isLoadingEspecialidades),
                        ),
                        const SizedBox(height: 15),

                        // --- 3. DROPDOWN DE MÉDICO (DINÂMICO) ---
                        _buildDropdownHeader('Médico'),
                        DropdownButtonFormField<Doctor>(
                          value: _selectedMedico,
                          hint: const Text('Selecione o médico'),
                          disabledHint:
                              const Text('Selecione a especialidade'),
                          isExpanded: true,
                          items: _isLoadingMedicos
                              ? []
                              : _listaMedicos
                                  .map((medico) => DropdownMenuItem(
                                        value: medico,
                                        child: Text(medico.fullName,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                          onChanged: _isSaving || _selectedEspecialidade == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedMedico = value;
                                  });
                                },
                          decoration: _buildDropdownDecoration(
                              isLoading: _isLoadingMedicos),
                        ),
                        const SizedBox(height: 15),

                        // --- 4. DATA ---
                        _buildDropdownHeader('Data da Consulta'),
                        GestureDetector(
                          onTap: _isSaving || _selectedMedico == null
                              ? null
                              : _selecionarData,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: _buildInputDecoration(
                                isEnabled: _selectedMedico != null),
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate!)
                                  : 'Selecione a data',
                              style: _buildTextStyle(
                                  isSelected: _selectedDate != null),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- 5. HORÁRIO ---
                        _buildDropdownHeader('Horário da Consulta'),
                        GestureDetector(
                          onTap: _isSaving || _selectedDate == null
                              ? null
                              : _selecionarHorario,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: _buildInputDecoration(
                                isEnabled: _selectedDate != null),
                            child: Text(
                              _isLoadingHorarios // Mostra loading se estiver buscando
                                  ? 'Carregando horários...'
                                  : _selectedHorario ?? 'Selecione o horário',
                              style: _buildTextStyle(
                                  isSelected: _selectedHorario != null),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // --- BOTÕES ---
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

  // --- MÉTODOS HELPERS DE UI ---
  Widget _buildDropdownHeader(String title) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  InputDecoration _buildDropdownDecoration({bool isLoading = false}) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
      suffixIcon: isLoading
          ? const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
    );
  }

  BoxDecoration _buildInputDecoration({bool isEnabled = true}) {
    return BoxDecoration(
      color: isEnabled ? Colors.grey.shade100 : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    );
  }

  TextStyle _buildTextStyle({bool isSelected = true}) {
    return TextStyle(
      color: isSelected ? Colors.black : Colors.grey.shade700,
    );
  }

  // --- MÉTODOS DE SELEÇÃO DE DATA/HORA ---
  Future<void> _selecionarData() async {
    // (O código do showDatePicker continua o mesmo)
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedHorario = null; // Reseta o horário
        _isLoadingHorarios = true; // Ativa o loading dos slots
        _horariosOcupados.clear(); // Limpa os horários antigos
      });

      // vvvv INÍCIO DA NOVA LÓGICA vvvv
      try {
        // Busca os horários exatos da API (ex: ["2025-11-20T10:30:00Z"])
        final horariosIso = await _apiService.getHorariosOcupados(
          _selectedMedico!.id,
          _selectedDate!,
        );

        // Converte as ISO strings em horários "HH:mm"
        // e aplica a regra de conflito de 30 minutos
        final Set<String> horariosConflitantes = {};

        for (final isoString in horariosIso) {
          // Converte para a hora local do dispositivo
          final dataHoraOcupada = DateTime.parse(isoString).toLocal();

          // Adiciona o slot exato
          horariosConflitantes.add(DateFormat('HH:mm').format(dataHoraOcupada));

          // Adiciona a "janela de conflito" (30 min antes e 30 min depois)
          // Se o médico tem consulta 10:30, o slot 10:00 fica indisponível.
          final trintaMinAntes =
              dataHoraOcupada.subtract(const Duration(minutes: 30));
          horariosConflitantes
              .add(DateFormat('HH:mm').format(trintaMinAntes));

          // Se o médico tem consulta 10:00, o slot 10:30 fica indisponível.
          final trintaMinDepois =
              dataHoraOcupada.add(const Duration(minutes: 30));
          horariosConflitantes
              .add(DateFormat('HH:mm').format(trintaMinDepois));
        }

        if (!mounted) return;
        setState(() {
          _horariosOcupados = horariosConflitantes;
          _isLoadingHorarios = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoadingHorarios = false;
        });
        _showError("Erro ao buscar horários: $e");
      }
      // ^^^^ FIM DA NOVA LÓGICA ^^^^
    }
  }

  
  List<String> _gerarHorariosMock() {
    List<String> horarios = [];
    
    // 1. Usa os mesmos horários da secretária (vai até 20:00)
    final TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
    final TimeOfDay end = const TimeOfDay(hour: 20, minute: 0); // <-- CORRIGIDO
    
    TimeOfDay atual = start;

    // 2. Loop para até ANTES das 20:00 (último slot será 19:30)
    while (atual.hour < end.hour ||
        (atual.hour == end.hour && atual.minute < end.minute)) // <-- CORRIGIDO
    {
      // 3. Usa a mesma regra de almoço da secretária (só pula 12:00 e 12:30)
      if (!(atual.hour == 12 && (atual.minute == 0 || atual.minute == 30))) { // <-- CORRIGIDO
        String hora = atual.hour.toString().padLeft(2, '0');
        String minuto = atual.minute.toString().padLeft(2, '0');
        horarios.add('$hora:$minuto');
      }

      // Lógica para adicionar 30 minutos (já estava correta no seu original)
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

  void _selecionarHorario() {
    // Se estiver carregando os horários, não abre o modal
    if (_isLoadingHorarios) {
      _showError("Carregando horários, aguarde...");
      return;
    }

    final List<String> horariosDisponiveis = _gerarHorariosMock();

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
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: horariosDisponiveis.length,
                    itemBuilder: (context, index) {
                      final horario = horariosDisponiveis[index];
                      final bool selecionado = _selectedHorario == horario;

                      // vvvv LÓGICA DE DESABILITAR vvvv
                      final bool isOcupado =
                          _horariosOcupados.contains(horario);
                      // ^^^^ FIM DA LÓGICA ^^^^

                      return GestureDetector(
                        // vvvv DESABILITA O CLIQUE vvvv
                        onTap: () {
                          if (isOcupado) {
                            // Se estiver ocupado, mostra o pop-up
                            _showHorarioOcupadoDialog();
                          } else {
                            // Se estiver livre, seleciona o horário
                            setState(() {
                              _selectedHorario = horario;
                            });
                            Navigator.pop(context);
                          }
                        },
                        // ^^^^ FIM DA CORREÇÃO ^^^^
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            // vvvv LÓGICA DE COR vvvv
                            color: selecionado
                                ? const Color(0xFF317714) // Selecionado
                                : isOcupado
                                    ? Colors.grey.shade300 // Ocupado
                                    : Colors.grey.shade100, // Livre
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selecionado
                                  ? const Color(0xFF317714)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            horario,
                            style: TextStyle(
                              // vvvv LÓGICA DE TEXTO vvvv
                              color: selecionado
                                  ? Colors.white
                                  : isOcupado
                                      ? Colors.grey.shade600 // Ocupado
                                      : Colors.black87, // Livre
                              fontWeight: selecionado
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              // Adiciona um "riscado" se estiver ocupado
                              decoration: isOcupado
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      );
                    },
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
}