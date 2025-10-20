// lib/views/pages/medico_dashboard_page.dart (VERSÃO COMPLETA E CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/paciente_controller.dart';
import '../../models/paciente.dart';
import '../widgets/paciente_card.dart';
import '../widgets/medico_app_bar.dart';

class MedicoDashboardPage extends StatefulWidget {
  const MedicoDashboardPage({super.key});

  @override
  State<MedicoDashboardPage> createState() => _MedicoDashboardPageState();
}

class _MedicoDashboardPageState extends State<MedicoDashboardPage> {
  final TextEditingController _anotacoesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final pacienteController = context.read<PacienteController>();
    pacienteController.addListener(_onControllerUpdate);
    _updateAnotacaoTextField(pacienteController);
  }

  @override
  void dispose() {
    context.read<PacienteController>().removeListener(_onControllerUpdate);
    _anotacoesController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    _updateAnotacaoTextField(context.read<PacienteController>());
    if (mounted) {
      setState(() {});
    }
  }

  void _updateAnotacaoTextField(PacienteController controller) {
    if (_anotacoesController.text != controller.anotacaoAtual) {
      _anotacoesController.text = controller.anotacaoAtual;
    }
  }

  static const Color primaryBlue = Color(0xFF5BBCDC);
  static const Color accentGreen = Color(0xFF42A01C);
  static const Color bg = Color(0xFFF3F6F8);

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  @override
  Widget build(BuildContext context) {
    final pacienteController = context.watch<PacienteController>();
    final today = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(today);

    return Scaffold(
      backgroundColor: bg,
      appBar: const MedicoAppBar(activePage: "Dashboard"),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna da esquerda
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: Container(
                  width: 270,
                  decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text("Pacientes do dia - $formattedDate", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const Divider(color: Colors.white70, thickness: 1, height: 0),
                      Expanded(child: _buildPacientesList(pacienteController)),
                      
                      // CORREÇÃO: BOTÃO "REAGENDAR DIA" ADICIONADO DE VOLTA
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 210,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(accentGreen),
                                shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              ),
                              child: const Text("Reagendar dia", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 15),
              // Coluna central
              Expanded(
                child: pacienteController.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : pacienteController.pacienteSelecionado == null
                        ? Center(
                            child: Text(
                              pacienteController.errorMessage ?? 'Nenhum paciente para exibir.',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          )
                        : _buildDashboardContent(context, pacienteController.pacienteSelecionado!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPacientesList(PacienteController controller) {
    if (controller.isLoading && controller.pacientes.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (controller.pacientes.isEmpty) {
      return const Center(child: Text('Nenhum paciente para hoje.', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: controller.pacientes.length,
      itemBuilder: (context, index) {
        final p = controller.pacientes[index];
        return PatientCard(
          paciente: p,
          selected: index == controller.selectedIndex,
          onTap: () => controller.selecionarPaciente(index),
        );
      },
    );
  }

  Widget _buildDashboardContent(BuildContext context, Paciente pacienteSelecionado) {
    final pacienteController = context.read<PacienteController>();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        children: [
          // Linha 1: Infos Paciente e Consulta
          Expanded(
            flex: 225,
            child: Row(
              children: [
                // Card Info Paciente (sem alterações)
                Flexible(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 40, color: primaryBlue)),
                          const SizedBox(height: 12),
                          Text(pacienteSelecionado.nome, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(pacienteSelecionado.telefone, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(pacienteSelecionado.email, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                
                // CORREÇÃO APLICADA AQUI
                // Card Info Consulta com a estrutura Flexible restaurada
                // SUBSTITUA O FLEXIBLE DAQUI PARA BAIXO
                Flexible(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                    // ADICIONE O SIZEDBOX.EXPAND AQUI
                    child: SizedBox.expand(
                      child: Column(
                        // E AJUSTE O ALINHAMENTO PARA 'spaceEvenly'
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Informações da Consulta", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(pacienteSelecionado.horario)}", style: const TextStyle(color: Colors.white70)),
                          Text("Especialidade: ${pacienteSelecionado.especialidade}", style: const TextStyle(color: Colors.white70)),
                          Text("Profissional: ${pacienteSelecionado.profissional}", style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // Linha 2: Anotações e Histórico de Anotações
          Expanded(
            flex: 300,
            child: Row(
              children: [
                // Card Anotações
                Flexible(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Anotações da Consulta", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: pacienteController.isAnotacaoLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : TextField(
                                controller: _anotacoesController,
                                maxLines: null,
                                expands: true,
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: "Digite as anotações sobre a consulta atual...",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
                                ),
                                textAlignVertical: TextAlignVertical.top,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: pacienteController.isSaving ? null : () async {
                              final success = await pacienteController.salvarAnotacao(_anotacoesController.text);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? "Anotação salva com sucesso!" : "Erro ao salvar anotação."),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: accentGreen),
                            child: pacienteController.isSaving 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text("Salvar"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // Card Histórico de Anotações
                Flexible(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Histórico de Anotações", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Consumer<PacienteController>(
                            builder: (context, controller, child) {
                              if (controller.isHistoricoLoading) {
                                return const Center(child: CircularProgressIndicator(color: Colors.white));
                              }
                              final historicoFiltrado = controller.historicoConsultas.where((consulta) {
                                bool temAnotacao = consulta.anotacaoConteudo != null && consulta.anotacaoConteudo!.isNotEmpty;
                                bool naoEhConsultaAtual = !isSameDay(consulta.horario, pacienteSelecionado.horario);
                                return temAnotacao && naoEhConsultaAtual;
                              }).toList();
                              
                              if (historicoFiltrado.isEmpty) {
                                return const Center(child: Text("Nenhuma anotação anterior encontrada.", style: TextStyle(color: Colors.white70)));
                              }

                              return ListView.builder(
                                itemCount: historicoFiltrado.length,
                                itemBuilder: (context, index) {
                                  final consulta = historicoFiltrado[index];
                                  return Card(
                                    color: Colors.white.withOpacity(0.1),
                                    child: ListTile(
                                      title: Text("Consulta de ${DateFormat('dd/MM/yyyy').format(consulta.horario)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text("Anotação de ${DateFormat('dd/MM/yyyy').format(consulta.horario)}"),
                                            content: SingleChildScrollView(child: Text(consulta.anotacaoConteudo ?? "Sem conteúdo.")),
                                            actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fechar")) ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          
          // CORREÇÃO: A LINHA 3 INTEIRA FOI ADICIONADA DE VOLTA
          Expanded(
            flex: 250,
            child: Row(
              children: [
                // Card Histórico de Consultas
                Flexible(
                  flex: 2,
                  child: Container(
                     padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Histórico de Consultas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Consumer<PacienteController>(
                            builder: (context, controller, child) {
                              if (controller.isHistoricoLoading) {
                                return const Center(child: CircularProgressIndicator(color: Colors.white));
                              }
                              if (controller.historicoConsultas.isEmpty) {
                                return const Center(child: Text("Nenhuma consulta encontrada.", style: TextStyle(color: Colors.white70)));
                              }
                              return ListView.builder(
                                itemCount: controller.historicoConsultas.length,
                                itemBuilder: (context, index) {
                                  final consulta = controller.historicoConsultas[index];
                                  return Card(
                                    color: Colors.white.withOpacity(0.1),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(
                                        "${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(consulta.horario)} - ${consulta.status}",
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        "Especialidade: ${consulta.especialidade}",
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // Card Botões de Ação
                Flexible(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          // 👇 ATUALIZE O onPressed AQUI 👇
                          onPressed: () async {
                            final success = await pacienteController.finalizarConsulta(_anotacoesController.text);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? "Consulta finalizada com sucesso!" : "Erro ao finalizar consulta."),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 40)),
                          child: const Text("Finalizar Consulta"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}