// lib/views/pages/cancelar_consulta_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medlink/models/dashboard_data_model.dart';
import 'package:medlink/services/api_service.dart';

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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadConsultasPendentes();
  }

  Future<void> _loadConsultasPendentes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Reusa o método que busca consultas futuras (pendentes/confirmadas)
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

  Future<void> _confirmarCancelamento(ProximaConsulta consulta) async {
    setState(() => _isProcessing = true);

    try {
      // 1. Chama a API de cancelamento
      final success = await _apiService.pacienteCancelarConsulta(consulta.id);

      if (success) {
        // 2. Sucesso: Remove da lista local e mostra feedback
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
                      // Fecha o diálogo e volta para o dashboard
                      Navigator.of(dialogContext).pop();
                      // Força o recarregamento do dashboard
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/user/dashboard',
                        (Route<dynamic> route) => false,
                      );
                    },
                  ),
                ],
              );
            },
          );
        }
      } else {
        // Se a API retornar false (o que não deve acontecer com o 200 OK, mas como fallback)
        throw Exception('Falha desconhecida da API.');
      }
    } catch (e) {
      if (!mounted) return;
      // 3. Erro (ex: regra de 72h violada)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao cancelar: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _mostrarDialogoConfirmacao(ProximaConsulta consulta) {
    // 1. Checagem de antecedência (A REGRA DE NEGÓCIO DO FRONT-END)
    final difference = consulta.data.difference(DateTime.now());
    
    // A regra é que deve ter mais de 72h. Se tiver 3 dias ou mais, a API no back-end fará a checagem exata.
    // O aviso visual do Front-end é mais suave.
    if (difference.inDays < 3) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Atenção'),
            content: const Text(
                'O cancelamento deve ser feito com no mínimo 72 horas de antecedência. Caso contrário, a clínica pode aplicar taxas.'),
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
      return;
    }

    // 2. Diálogo de Confirmação Final
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Cancelamento'),
          content: Text(
            'Tem certeza que deseja cancelar sua consulta com ${consulta.medico} em ${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(consulta.data)}?',
          ),
          actions: [
            TextButton(
              child: const Text('Não'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop(); // Fecha o diálogo de confirmação
                      _confirmarCancelamento(consulta);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Sim, Cancelar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5BBCDC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: const Text('Cancelar Consulta', style: TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
            trailing: _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,))
                : const Icon(Icons.cancel, color: Colors.red),
            onTap: _isProcessing
                ? null
                : () => _mostrarDialogoConfirmacao(consulta),
          ),
        );
      },
    );
  }
}