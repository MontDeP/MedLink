// lib/views/pages/cancelar_consulta_page.dart (NOVO ARQUIVO)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart'; 
import 'package:medlink/services/api_service.dart';
import 'package:medlink/views/pages/remarcar_consulta_page.dart'; // Reutiliza o modelo de lista

class CancelarConsultaPage extends StatefulWidget {
  const CancelarConsultaPage({super.key});

  @override
  State<CancelarConsultaPage> createState() => _CancelarConsultaPageState();
}

class _CancelarConsultaPageState extends State<CancelarConsultaPage> {
  final ApiService _apiService = ApiService();

  List<ProximaConsulta>? _consultasPendentes;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;

  ProximaConsulta? _consultaSelecionada;
  final TextEditingController _motivoController = TextEditingController();

  // Cores do MedLink para harmonia
  static const Color primaryBlue = Color(0xFF5BBCDC);

  @override
  void initState() {
    super.initState();
    _loadConsultasPendentes();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _loadConsultasPendentes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Reutiliza o método que busca consultas futuras pendentes
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

  Future<void> _salvarCancelamento() async {
    if (_consultaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione uma consulta para cancelar.'))
      );
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final motivo = _motivoController.text.trim().isEmpty 
                     ? 'Cancelado pelo paciente via app' 
                     : _motivoController.text.trim();
      
      // Chamada à nova API de cancelamento do paciente
      final success = await _apiService.cancelarConsultaPaciente(
        _consultaSelecionada!.id, 
        motivo
      );

      if (success) {
         if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Consulta Cancelada!'),
                    content: const Text('Sua consulta foi cancelada com sucesso!'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(); 
                          // Redireciona para o Dashboard e força recarregamento
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
      } else {
        throw Exception('Falha da API ao cancelar.');
      }

    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar: ${e.toString().replaceFirst('Exception: ', '')}'), 
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
      backgroundColor: primaryBlue,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Text(
          _consultaSelecionada == null 
            ? 'Selecione a Consulta para Cancelar' 
            : 'Confirmar Cancelamento',
          style: const TextStyle(color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_consultaSelecionada != null) {
              setState(() {
                _consultaSelecionada = null;
                _motivoController.clear();
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
      return const Center(child: Text('Você não possui consultas futuras para cancelar.', style: TextStyle(color: Colors.white, fontSize: 16)));
    }

    if (_consultaSelecionada == null) {
      return _buildListaConsultas();
    }
    
    return _buildFormularioCancelamento();
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
              
              // 👇 VALIDAÇÃO: ANTECEDÊNCIA MÍNIMA DE 24 HORAS 👇
              if (difference.inHours < 24) {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Cancelamento Não Permitido'),
                      content: const Text('O cancelamento pelo aplicativo é permitido apenas com no mínimo 24 horas de antecedência. Por favor, ligue para a clínica.'),
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
                // Se for permitido, avança para o formulário de confirmação
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

  Widget _buildFormularioCancelamento() {
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
                // 👇 NOVO ESTILO: Título de Aviso Suave (Utiliza Colors.red.shade800 para a fonte) 👇
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50, // Fundo suave para aviso
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Você está prestes a CANCELAR a seguinte consulta:',
                        style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.red.shade800), // Cor forte, mas harmoniosa
                      ),
                      const SizedBox(height: 8),
                      Text('Especialidade: ${_consultaSelecionada!.especialidade}', style: const TextStyle(color: Colors.black87)),
                      Text('Médico: ${_consultaSelecionada!.medico}', style: const TextStyle(color: Colors.black87)),
                      Text('Data: ${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(_consultaSelecionada!.data)}', style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
                // 👆 FIM NOVO ESTILO 👆
                
                const Divider(height: 30),

                const Text(
                  'Motivo do Cancelamento (Opcional):',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: _motivoController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ex: Conflito de agenda, motivo pessoal...',
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade100, 
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _salvarCancelamento,
                    // 👇 NOVO ESTILO DO BOTÃO: Vermelho padrão, mas harmonioso 👇
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // Mantém o significado de cancelamento
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
                      : const Text('CONFIRMAR CANCELAMENTO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}