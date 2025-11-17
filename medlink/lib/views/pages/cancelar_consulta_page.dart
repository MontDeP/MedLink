// lib/views/pages/cancelar_consulta_page.dart
// (Baseado no seu remarcar_consulta_page.dart)

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
  bool _isSaving = false; // Para controlar o loading do cancelamento

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
      // Reutiliza a mesma chamada de API que busca consultas pendentes
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

  // Helper de erro
  void _showError(String message) {
    if (!mounted) return;
    // Tenta extrair a mensagem de erro específica do Django
    String cleanMessage = message;
    if (message.contains("Exception: ")) {
      cleanMessage = message.split("Exception: ")[1];
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(cleanMessage),
          backgroundColor: Colors.red),
    );
  }

  // Lógica de confirmação e chamada da API de cancelamento
  Future<void> _showCancelConfirmationDialog(ProximaConsulta consulta) async {
    // 1. VERIFICA A REGRA DE 24H (Regra do Front-end)
    final difference = consulta.data.difference(DateTime.now());
    if (difference.inHours < 24) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Atenção'),
            content: const Text(
                'Não é possível cancelar consultas com menos de 24 horas de antecedência. Por favor, entre em contato com a clínica.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        },
      );
      return; // Para a execução aqui
    }

    // 2. SE ESTIVER OK, MOSTRA A CONFIRMAÇÃO
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Cancelamento'),
          content: Text(
              'Tem certeza que deseja cancelar a consulta de ${consulta.especialidade} com ${consulta.medico} no dia ${DateFormat('dd/MM').format(consulta.data)}?'),
          actions: [
            TextButton(
              child: const Text('Não'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Sim, cancelar'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    // 3. SE CONFIRMOU, CHAMA A API
    if (confirmed == true) {
      setState(() => _isSaving = true); // Ativa o loading
      try {
        // Chama a função da API que criamos no passo anterior
        final success =
            await _apiService.cancelarConsultaPaciente(consulta.id);
        
        if (success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Consulta cancelada com sucesso!'),
                backgroundColor: Colors.green),
          );
          _loadConsultasPendentes(); // Recarrega a lista (a consulta cancelada sumirá)
        } else {
          // O backend (Django) pode ter recusado (ex: consulta já paga)
          // Mas o backend já trata o erro 500, então vamos lançar um erro genérico
          throw Exception('A API recusou o cancelamento. Tente novamente.');
        }
      } catch (e) {
        if (!mounted) return;
        // A API (Django) vai retornar a mensagem de erro que configuramos (400)
        _showError(e.toString());
      } finally {
        if (mounted) {
          setState(() => _isSaving = false); // Desativa o loading
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5BBCDC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: const Text(
          'Cancelar Consulta',
          style: TextStyle(color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
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
      return Center(
          child:
              Text(_errorMessage!, style: const TextStyle(color: Colors.white)));
    }

    if (_consultasPendentes == null || _consultasPendentes!.isEmpty) {
      return const Center(
          child: Text('Você não possui consultas para cancelar.',
              style: TextStyle(color: Colors.white, fontSize: 16)));
    }

    // Se houver consultas, mostra a lista
    return _buildListaConsultas();
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
            trailing: IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Cancelar consulta',
              // Desativa o botão se já estiver salvando/cancelando
              onPressed: _isSaving
                  ? null 
                  : () => _showCancelConfirmationDialog(consulta),
            ),
          ),
        );
      },
    );
  }
}