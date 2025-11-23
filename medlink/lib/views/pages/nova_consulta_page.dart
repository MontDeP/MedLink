// lib/views/pages/nova_consulta_page.dart (MODIFICADA PARA CHAMAR API)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart'; 
import 'package:medlink/services/api_service.dart';
import 'package:intl/date_symbol_data_local.dart'; 


// --- ESTRUTURAS DE DADOS SIMPLIFICADAS ---
class Clinica { final int id; final String nome; Clinica({required this.id, required this.nome}); }
class Especialidade { final String key; final String nome; Especialidade({required this.key, required this.nome}); }
class MedicoSelecionavel { final int id; final String nome; final String especialidade; MedicoSelecionavel({required this.id, required this.nome, required this.especialidade}); }


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
  
  // --- NOVOS ESTADOS PARA A CASCATA DE SELEÇÃO ---
  List<Clinica> _clinicas = [];
  List<Especialidade> _especialidades = [];
  List<MedicoSelecionavel> _medicos = [];
  List<String> _horariosDisponiveis = [];

  Clinica? _selectedClinica;
  Especialidade? _selectedEspecialidade;
  MedicoSelecionavel? _selectedMedico;
  
  DateTime? _selectedDate;
  String? _selectedHorario;

  bool _isClinicaLoading = true;
  bool _isEspecialidadeLoading = false;
  bool _isMedicoLoading = false;
  bool _isHorarioLoading = false;
  
  String? _errorMessage;
  // --- FIM DOS NOVOS ESTADOS ---


  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
    _loadClinicas();
  }
  
  // --- NOVAS FUNÇÕES DE CARREGAMENTO ---
  Future<void> _loadClinicas() async {
    setState(() {
      _isClinicaLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.getClinicas();
      _clinicas = data.map((c) => Clinica(id: c['id'] as int, nome: c['nome'] as String)).toList();
    } catch (e) {
      _errorMessage = 'Erro ao carregar clínicas: $e';
    } finally {
      setState(() => _isClinicaLoading = false);
    }
  }

  Future<void> _loadEspecialidades(int clinicaId) async {
    setState(() {
      _isEspecialidadeLoading = true;
      _medicos = [];
      _horariosDisponiveis = [];
      _selectedEspecialidade = null;
      _selectedMedico = null;
      _selectedDate = null;
      _selectedHorario = null;
    });
    try {
      final data = await _apiService.getEspecialidadesPorClinica(clinicaId);
      _especialidades = data.map((e) => Especialidade(key: e['key'] as String, nome: e['nome'] as String)).toList();
    } catch (e) {
      _errorMessage = 'Erro ao carregar especialidades: $e';
    } finally {
      setState(() => _isEspecialidadeLoading = false);
    }
  }

  Future<void> _loadMedicos(int clinicaId, String especialidadeKey) async {
    setState(() {
      _isMedicoLoading = true;
      _horariosDisponiveis = [];
      _selectedMedico = null;
      _selectedDate = null;
      _selectedHorario = null;
    });
    try {
      final data = await _apiService.getMedicosPorEspecialidade(clinicaId, especialidadeKey);
      _medicos = data.map((m) => MedicoSelecionavel(
        id: m['id'] as int, 
        nome: m['nome'] as String, 
        especialidade: m['especialidade'] as String
      )).toList();
    } catch (e) {
      _errorMessage = 'Erro ao carregar médicos: $e';
    } finally {
      setState(() => _isMedicoLoading = false);
    }
  }
  
  Future<void> _loadHorariosDisponiveis(int medicoId, DateTime data) async {
    if (_isHorarioLoading) return;

    setState(() {
      _isHorarioLoading = true;
      _horariosDisponiveis = [];
      _selectedHorario = null;
    });
    try {
      final horarios = await _apiService.getHorariosDisponiveis(medicoId, data);
      _horariosDisponiveis = horarios;
    } catch (e) {
      _errorMessage = 'Erro ao carregar horários: $e';
    } finally {
      setState(() => _isHorarioLoading = false);
    }
  }
  
  // --- LÓGICA DE SALVAR ATUALIZADA ---
  Future<void> _salvarNovaConsulta() async {
    if (_selectedClinica == null || 
        _selectedMedico == null ||
        _selectedDate == null ||
        _selectedHorario == null) {
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
      final parts = _selectedHorario!.split(':');
      final novaDataHora = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      // Chama a API com os IDs (medico_id, clinica_id)
      await _apiService.pacienteMarcarConsulta(
          _selectedClinica!.id, 
          _selectedMedico!.id, 
          novaDataHora
      );
      
      if (!mounted) return;

      // 👇 INÍCIO DA MODIFICAÇÃO: Pop-up de Sucesso e Redirecionamento 👇
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Consulta Marcada!'),
            content: const Text('Sua consulta foi agendada com sucesso e está pendente de confirmação.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  // Fecha o diálogo
                  Navigator.of(dialogContext).pop(); 
                  // Redireciona para o Dashboard do Paciente e limpa a pilha de navegação
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/user/dashboard', 
                    (Route<dynamic> route) => false
                  );
                },
              ),
            ],
          );
        },
      );
      // 👆 FIM DA MODIFICAÇÃO 👆

    } on Exception catch (e) { 
      if (!mounted) return;
      // Captura o erro do backend e exibe a mensagem (ex: conflito de horário)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }


  void _abrirSeletorDeHorario(BuildContext context) {
    if (_selectedMedico == null || _selectedDate == null) return;
    
    // Recarrega os horários antes de abrir (boa prática)
    _loadHorariosDisponiveis(_selectedMedico!.id, _selectedDate!).then((_) {
        // Se ainda houver horários e o widget estiver montado, abre o dialog
        if (_horariosDisponiveis.isNotEmpty && mounted) {
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
                           children: _horariosDisponiveis.map((horario) {
                             final bool selecionado = _selectedHorario == horario;
                             return GestureDetector(
                               onTap: () {
                                 setState(() {
                                   _selectedHorario = horario;
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
        } else if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('Nenhum horário disponível neste dia.'),
                 backgroundColor: Colors.orange,
               ),
             );
        }
    });

  }
  
  // --- NOVA FUNÇÃO PARA FORMATAR O NOME ---
  String _formatarNomeMedico(String nomeCompleto) {
    // Lógica para detectar se o nome já tem prefixo (ex: Dr. ou Dra.)
    if (nomeCompleto.toLowerCase().startsWith('dr.') || nomeCompleto.toLowerCase().startsWith('dra.')) {
      return nomeCompleto;
    }
    
    // Se não tiver, adiciona o prefixo Dr(a)
    return 'Dr(a) $nomeCompleto';
  }
  // --- FIM DA NOVA FUNÇÃO ---


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
                          'Nova Consulta',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_errorMessage != null) 
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                          ),
                        const SizedBox(height: 20),
                        
                        // --- 1. SELEÇÃO DE CLÍNICA ---
                        _buildSectionTitle('Clínica'),
                        _isClinicaLoading ? const Center(child: CircularProgressIndicator()) :
                        DropdownButtonFormField<Clinica>(
                          value: _selectedClinica,
                          items: _clinicas
                              .map((c) => DropdownMenuItem(value: c, child: Text(c.nome)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedClinica = value;
                              _selectedEspecialidade = null;
                              _selectedMedico = null;
                            });
                            if (value != null) _loadEspecialidades(value.id);
                          },
                          decoration: _inputDecoration(),
                        ),
                        const SizedBox(height: 15),

                        // --- 2. SELEÇÃO DE ESPECIALIDADE ---
                        _buildSectionTitle('Especialidade'),
                        _isEspecialidadeLoading ? const Center(child: CircularProgressIndicator()) :
                        DropdownButtonFormField<Especialidade>(
                          value: _selectedEspecialidade,
                          items: _especialidades
                              .map((e) => DropdownMenuItem(value: e, child: Text(e.nome)))
                              .toList(),
                          onChanged: _selectedClinica == null ? null : (value) {
                            setState(() {
                              _selectedEspecialidade = value;
                              _selectedMedico = null;
                            });
                            if (value != null && _selectedClinica != null) {
                               _loadMedicos(_selectedClinica!.id, value.key);
                            }
                          },
                          decoration: _inputDecoration(),
                        ),
                        const SizedBox(height: 15),

                        // --- 3. SELEÇÃO DE MÉDICO ---
                        _buildSectionTitle('Médico'),
                        _isMedicoLoading ? const Center(child: CircularProgressIndicator()) :
                        DropdownButtonFormField<MedicoSelecionavel>(
                          value: _selectedMedico,
                          items: _medicos
                              .map((m) => DropdownMenuItem(
                                    value: m, 
                                    child: Text(_formatarNomeMedico(m.nome))
                                  ))
                              .toList(),
                          onChanged: _selectedEspecialidade == null ? null : (value) {
                            setState(() {
                              _selectedMedico = value;
                              _selectedDate = null;
                              _selectedHorario = null;
                            });
                          },
                          decoration: _inputDecoration(),
                        ),
                        const SizedBox(height: 15),

                        // --- 4. SELEÇÃO DE DATA ---
                        _buildSectionTitle('Data da Consulta'),
                        GestureDetector(
                          onTap: _selectedMedico == null ? null : () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now().add(const Duration(days: 1)),
                              lastDate: DateTime(2030),
                              locale: const Locale('pt', 'BR'),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                                _selectedHorario = null;
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: _selectedMedico == null ? Colors.grey.shade200 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate!)
                                  : 'Selecione a data',
                              style: TextStyle(
                                color: _selectedDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // --- 5. SELEÇÃO DE HORÁRIO ---
                        _buildSectionTitle('Horário da Consulta'),
                        GestureDetector(
                          onTap: _selectedDate == null ? null : () => _abrirSeletorDeHorario(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: _selectedDate == null ? Colors.grey.shade200 : (_isHorarioLoading ? Colors.orange.shade100 : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _isHorarioLoading 
                              ? const Text('Carregando horários...', style: TextStyle(color: Colors.orange))
                              : Text(
                                _selectedHorario ?? 'Selecione o horário',
                                style: TextStyle(
                                  color: _selectedHorario != null
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // --- BOTÕES ---
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
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
                                onPressed: _isSaving ? null : _salvarNovaConsulta,
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
  
  // Helper para o estilo dos Dropdowns
  Widget _buildSectionTitle(String title) {
     return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        );
  }
  
  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }
}