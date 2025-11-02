// lib/views/pages/remarcar_consulta_page.dart (COM POP-UP DE AVISO)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart'; 
import 'package:medlink/services/api_service.dart';
import 'package:medlink/views/pages/nova_consulta_page.dart';

// ... resto dos seus imports e o código da classe

class RemarcarConsultaPage extends StatefulWidget {
  const RemarcarConsultaPage({super.key});

  @override
  State<RemarcarConsultaPage> createState() => _RemarcarConsultaPageState();
}

class _RemarcarConsultaPageState extends State<RemarcarConsultaPage> {
  final ApiService _apiService = ApiService();

  List<ProximaConsulta>? _consultasPendentes;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;

  ProximaConsulta? _consultaSelecionada;
  DateTime? _selectedDate;
  String? _selectedHorario;

  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConsultasPendentes();
  }

  @override
  void dispose() {
    _dataController.dispose();
    _horarioController.dispose();
    super.dispose();
  }

  Future<void> _loadConsultasPendentes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final consultas = await _apiService.getPacienteConsultasPendentes();
      setState(() {
        _consultasPendentes = consultas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erro ao carregar consultas: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime dataMinima = DateTime.now().add(const Duration(days: 3));

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _consultaSelecionada!.data.isAfter(dataMinima) 
                   ? _consultaSelecionada!.data 
                   : dataMinima,
      firstDate: dataMinima.subtract(const Duration(days: 1)),
      lastDate: DateTime(2030),
      selectableDayPredicate: (DateTime day) {
        return day.isAfter(DateTime.now().add(const Duration(days: 2)));
      },
      helpText: 'Só é possível remarcar para daqui a 3 dias.',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dataController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

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
                      final bool selecionado = _selectedHorario == horario;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedHorario = horario;
                            _horarioController.text = horario;
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
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            horario,
                            style: TextStyle(
                              color: selecionado ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _salvarRemarcacao() async {
    if (_consultaSelecionada == null || _selectedDate == null || _selectedHorario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, preencha todos os campos.'))
      );
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

      final success = await _apiService.remarcarConsultaPaciente(
        _consultaSelecionada!.id, 
        novaDataHora
      );

      if (success) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consulta remarcada com sucesso!'), backgroundColor: Colors.green)
        );
        Navigator.pop(context); // Volta para a lista de consultas
      } else {
        throw Exception('Falha da API ao remarcar.');
      }

    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remarcar: $e'), backgroundColor: Colors.red,)
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5BBCDC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Text(
          _consultaSelecionada == null 
            ? 'Selecione a Consulta' 
            : 'Remarcar Consulta',
          style: const TextStyle(color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_consultaSelecionada != null) {
              setState(() {
                _consultaSelecionada = null;
                _selectedDate = null;
                _selectedHorario = null;
                _dataController.clear();
                _horarioController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)));
    }

    if (_consultasPendentes == null || _consultasPendentes!.isEmpty) {
      return const Center(child: Text('Você não possui consultas para remarcar.', style: TextStyle(color: Colors.white, fontSize: 16)));
    }

    if (_consultaSelecionada == null) {
      return _buildListaConsultas();
    }
    
    return _buildFormularioRemarcacao();
  }

 
  Widget _buildListaConsultas() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _consultasPendentes!.length,
      itemBuilder: (context, index) {
        final consulta = _consultasPendentes![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(consulta.especialidade),
            subtitle: Text(
                'Com ${consulta.medico}\n${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(consulta.data)}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // --- INÍCIO DA ALTERAÇÃO ---
              // 1. Verifica a regra dos 3 dias
              final difference = consulta.data.difference(DateTime.now());

              if (difference.inDays < 3) {
                // Se a regra for violada, mostra o pop-up de erro
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Atenção'),
                      content: const Text(
                          'Não é possível remarcar consultas com menos de 3 dias de antecedência.'),
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
              } else {
                // 2. Se a regra for OK, navega para a tela de Nova Consulta
                //    passando a consulta antiga para pré-preenchimento.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NovaConsultaPage(
                      isRescheduling: true,
                      consultaAntiga: consulta,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildFormularioRemarcacao() {
    return Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remarcando: ${_consultaSelecionada!.especialidade}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Data original: ${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(_consultaSelecionada!.data)}',
                   style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Especialidade',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: TextEditingController(text: _consultaSelecionada!.especialidade),
                  readOnly: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade200, 
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Médico',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: TextEditingController(text: _consultaSelecionada!.medico),
                  readOnly: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Nova Data da Consulta',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () => _selecionarData(context), 
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dataController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Selecione a nova data',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Novo Horário da Consulta',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () => _abrirSeletorDeHorario(context),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _horarioController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Selecione o novo horário',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: _isSaving ? null : _salvarRemarcacao,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF317714),
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
                    : const Text('Salvar Remarcação'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}