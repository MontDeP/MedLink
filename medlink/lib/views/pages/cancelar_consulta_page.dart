// lib/views/pages/cancelar_consulta_page.dart (COM POP-UP DE SUCESSO)
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

  bool _isCanceling = false;
  int? _cancelingId; 

  @override
  void initState() {
    super.initState();
    _loadConsultasPendentes();
  }

  Future<void> _loadConsultasPendentes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isCanceling = false;
      _cancelingId = null;
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

  Future<void> _showConfirmarCancelamentoDialog(ProximaConsulta consulta) async {
    bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Cancelamento'),
          content: Text(
              'Tem certeza que deseja cancelar a consulta de ${consulta.especialidade} com ${consulta.medico} no dia ${DateFormat('dd/MM/yyyy').format(consulta.data)}?'),
          actions: [
            TextButton(
              child: const Text('Não'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sim, Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      _cancelarConsulta(consulta.id);
    }
  }

  // --- FUNÇÃO MODIFICADA ---
  Future<void> _cancelarConsulta(int consultaId) async {
    setState(() {
      _isCanceling = true;
      _cancelingId = consultaId;
    });

    try {
      final success = await _apiService.pacienteCancelarConsulta(consultaId);

      // --- INÍCIO DA MODIFICAÇÃO ---
      if (success) {
        if (!mounted) return;

        // 1. Mostra o Pop-up de sucesso
        await showDialog(
          context: context,
          barrierDismissible: false, // Impede de fechar clicando fora
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Sucesso!'),
              content: const Text('Consulta cancelada com sucesso!'), // Sua mensagem
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

        // 2. Após fechar o pop-up, fecha a página de "CancelarConsultaPage"
        // Isso vai automaticamente voltar para a Home e disparar o refresh.
        if (mounted) {
          Navigator.of(context).pop();
        }
        // Não precisamos mais do _loadConsultasPendentes() aqui.

      // --- FIM DA MODIFICAÇÃO ---

      } else {
        throw Exception('A API retornou falha.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cancelar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isCanceling = false;
        _cancelingId = null;
      });
    }
    // O finally não é mais necessário aqui, pois a página será fechada.
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
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)));
    }

    if (_consultasPendentes == null || _consultasPendentes!.isEmpty) {
      return const Center(child: Text('Você não possui consultas para cancelar.', style: TextStyle(color: Colors.white, fontSize: 16)));
    }
    
    return _buildListaConsultas();
  }
 
  Widget _buildListaConsultas() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _consultasPendentes!.length,
      itemBuilder: (context, index) {
        final consulta = _consultasPendentes![index];
        final bool isEsteItemCarregando = _isCanceling && _cancelingId == consulta.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(consulta.especialidade, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Com ${consulta.medico}\n${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(consulta.data)}'),
            isThreeLine: true,
            
            trailing: isEsteItemCarregando
              ? const SizedBox(
                  width: 24, 
                  height: 24, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                )
              : IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  tooltip: 'Cancelar',
                  onPressed: () => _showConfirmarCancelamentoDialog(consulta),
                ),
            
            onTap: isEsteItemCarregando ? null : () => _showConfirmarCancelamentoDialog(consulta),
          ),
        );
      },
    );
  }
}
