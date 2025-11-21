// lib/views/pages/nova_consulta_page.dart (MODIFICADA PARA CHAMAR API)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart'; 
// --- IMPORT ADICIONADO ---
import 'package:medlink/services/api_service.dart';

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
  // --- ESTADOS ADICIONADOS ---
  final ApiService _apiService = ApiService();
  bool _isSaving = false;
  // --- FIM DOS ESTADOS ADICIONADOS ---

  String? selectedEspecialidade;
  String? selectedMedico;
  DateTime? selectedDate;
  String? selectedHorario;

  // Listas (agora dentro do State para podermos modificar)
  final List<String> especialidades = [
    'Cardiologista',
    'Dermatologista',
    'Neurologista',
    'Clínico Geral'
  ];

  final List<String> medicos = [
    'Dra. Ana Oliveira',
    'Dr. Bruno Souza',
    'Dra. Carla Mendes',
    'Dr. Daniel Lima'
  ];

  // (O método initState() permanece o mesmo)
  @override
  void initState() {
    super.initState();
    if (widget.isRescheduling && widget.consultaAntiga != null) {
      final especialidadeAntiga = widget.consultaAntiga!.especialidade;
      final medicoAntigo = widget.consultaAntiga!.medico;
      if (!especialidades.contains(especialidadeAntiga)) {
        especialidades.insert(0, especialidadeAntiga);
      }
      if (!medicos.contains(medicoAntigo)) {
        medicos.insert(0, medicoAntigo);
      }
      selectedEspecialidade = especialidadeAntiga;
      selectedMedico = medicoAntigo;
    }
  }

  // (Os métodos gerarHorarios() e _abrirSeletorDeHorario() permanecem os mesmos)
  List<String> gerarHorarios() {
    List<String> horarios = [];
    TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 30);
    TimeOfDay atual = start;
    while (atual.hour < end.hour || (atual.hour == end.hour && atual.minute <= end.minute)) {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              color: selecionado ? Colors.white : Colors.black87,
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

  // --- LÓGICA DE SALVAR ATUALIZADA ---
  Future<void> _salvarNovaConsulta() async {
    // 1. Validação dos campos
    if (selectedEspecialidade == null ||
        selectedMedico == null ||
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

    // 2. Inicia o loading
    setState(() => _isSaving = true);

    try {
      // 3. Monta o objeto DateTime
      final parts = selectedHorario!.split(':');
      final novaDataHora = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      // 4. Chama a API
      // (Se for reagendamento, chama a API de remarcar; senão, chama a de marcar)
      bool success;
      if (widget.isRescheduling) {
        success = await _apiService.remarcarConsultaPaciente(
          widget.consultaAntiga!.id,
          novaDataHora,
        );
      } else {
        success = await _apiService.pacienteMarcarConsulta(
          selectedEspecialidade!,
          selectedMedico!,
          novaDataHora,
        );
      }
      
      if (!mounted) return; // Checagem de segurança

      // 5. Trata a resposta
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
        Navigator.pop(context); // Fecha a tela
      } else {
        throw Exception(
          widget.isRescheduling ? 'Falha ao remarcar' : 'Falha ao marcar',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // 6. Para o loading
      setState(() => _isSaving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    // (O build() principal permanece o mesmo)
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
                        
                        // (Os campos de Especialidade e Médico permanecem os mesmos)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Especialidade',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<String>(
                          value: selectedEspecialidade,
                          items: especialidades
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedEspecialidade = value;
                            });
                          },
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<String>(
                          value: selectedMedico,
                          items: medicos
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedMedico = value;
                            });
                          },
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 15),

                        // (Os campos de Data e Horário permanecem os mesmos)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Nova Data da Consulta',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
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
                              border: Border.all(color: Colors.grey.shade300),
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
                            style: TextStyle(fontSize: 14, color: Colors.grey),
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
                              border: Border.all(color: Colors.grey.shade300),
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

                        // --- BOTÕES ATUALIZADOS ---
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                // Desabilita o botão de cancelar durante o save
                                onPressed: _isSaving ? null : () {
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
                                // Chama a nova função _salvarNovaConsulta
                                // e desabilita o botão se _isSaving for true
                                onPressed: _isSaving ? null : _salvarNovaConsulta,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF317714),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                // Mostra o loading ou o texto
                                child: _isSaving 
                                  ? const SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(
                                        color: Colors.white, 
                                        strokeWidth: 2,
                                      )
                                    )
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