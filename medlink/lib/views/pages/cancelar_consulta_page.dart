// lib/views/pages/cancelar_consulta_page.dart (COM A LÓGICA DE 24H NO FRONTEND)

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
      // Esta função já busca 'pendente', 'confirmada' e 'reagendada'
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

  // --- INÍCIO DA MODIFICAÇÃO (NOVA FUNÇÃO DE ERRO) ---
  Future<void> _showErro24hDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Impede de fechar clicando fora
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Atenção'),
          content: const Text(
              'Consultas não podem ser canceladas com menos de 24h de antecedência.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 1. Fecha o pop-up
              },
            ),
          ],
        );
      },
    );

    // 2. Após fechar o pop-up, volta para a Home (como você pediu)
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  // --- FIM DA MODIFICAÇÃO ---

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
      _cancelarConsulta(consulta.id); // Esta função (abaixo) não mudou
    }
  }

  // Esta função continua a mesma, pois ela só lida com o SUCESSO
  // ou com erros da API (que não sejam o erro de 24h)
  Future<void> _cancelarConsulta(int consultaId) async {
    setState(() {
      _isCanceling = true;
      _cancelingId = consultaId;
    });

    try {
      final success = await _apiService.pacienteCancelarConsulta(consultaId);

      if (success) {
        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false, 
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Sucesso!'),
              content: const Text('Consulta cancelada com sucesso!'), 
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

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '');

      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Não foi possível cancelar'),
            content: Text(errorMessage), 
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

      setState(() {
        _isCanceling = false;
        _cancelingId = null;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5BBCDC),
      appBar: AppBar(
        // ... (o AppBar continua o mesmo) ...
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
    // ... (o _buildBody continua o mesmo) ...
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

        // --- INÍCIO DA MODIFICAÇÃO (NOVA LÓGICA DE CLIQUE) ---
        final VoidCallback onCancelPressed = () {
          // 1. Calcula a diferença de tempo
          final difference = consulta.data.difference(DateTime.now());
          
          // 2. Verifica a regra (igual à do backend: < 1 dia)
          //
          if (difference.inDays < 1) { 
            // 3. Se violar a regra, mostra o pop-up de erro (que redireciona pra Home)
            _showErro24hDialog();
          } else {
            // 4. Se a regra estiver OK, mostra o pop-up de confirmação
            _showConfirmarCancelamentoDialog(consulta);
          }
        };
        // --- FIM DA MODIFICAÇÃO ---

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
                  onPressed: onCancelPressed, // <-- Lógica nova aplicada
                ),
            
            onTap: isEsteItemCarregando ? null : onCancelPressed, // <-- Lógica nova aplicada
          ),
        );
      },
    );
  }
}