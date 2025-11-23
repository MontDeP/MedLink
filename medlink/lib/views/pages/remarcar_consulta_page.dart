// lib/views/pages/remarcar_consulta_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart'; 
import 'package:medlink/services/api_service.dart';

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
    // A validação de 3 dias deve ser feita ANTES de abrir o date picker
    final DateTime dataMinima = DateTime.now().add(const Duration(days: 3));
    
    // As consultas só podem ser remarcadas se a data AGORA estiver a 3 dias ou mais de distância
    // Mas o date picker deve permitir datas a partir de hoje + 3 dias.
    DateTime dataInicial = _consultaSelecionada!.data.isAfter(dataMinima) 
                   ? _consultaSelecionada!.data 
                   : dataMinima;
    if (dataInicial.isBefore(dataMinima)) {
        dataInicial = dataMinima;
    }


    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      selectableDayPredicate: (DateTime day) {
        // Regras de validação (Dias Úteis e Mínimo 3 dias de antecedência)
        bool isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
        bool isBeforeMinDate = day.isBefore(dataMinima);
        
        return !isWeekend && !isBeforeMinDate;
      },
      helpText: 'Só é possível remarcar para dias úteis, com mínimo de 3 dias de antecedência.',
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dataController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // A função gerarHorarios() do remarcamento não precisa de lógica de API,
  // pois ela apenas gera a lista de opções a serem checadas na API.
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
    // Nota: O Front-end de Remarcação (Flutter) não possui a lógica de API para buscar horários.
    // Usamos a lista estática e a API do backend faz a checagem de conflito no PATCH.
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
         // 👇 INÍCIO DA MODIFICAÇÃO: Pop-up de Sucesso e Redirecionamento 👇
         if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Consulta Reagendada!'),
                    content: const Text('Sua consulta foi reagendada com sucesso e o médico/secretária verá a nova data.'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(); 
                          // Redireciona para o Dashboard do Paciente e FORÇA RECARREGAMENTO
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/user/dashboard', 
                            (Route<dynamic> route) => false
                          );
                        },
                      ),
                    ],
                  );
                },
              );
          }
         // 👆 FIM DA MODIFICAÇÃO 👆
      } else {
        throw Exception('Falha da API ao remarcar.');
      }

    } catch(e) {
      if (!mounted) return;
      // Captura o erro do backend e exibe a mensagem
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remarcar: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      if(mounted) setState(() => _isSaving = false);
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
            subtitle: Text('Com ${consulta.medico}\n${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(consulta.data)}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              final difference = consulta.data.difference(DateTime.now());
              
              if (difference.inDays < 3) {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Atenção'),
                      content: const Text('Não é possível remarcar consultas com menos de 3 dias de antecedência.'),
                      actions: [
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(); 
                          },
                        ),
                      ],
                    );
                  },
                );
              } else {
                setState(() {
                  _consultaSelecionada = consulta;
                });
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