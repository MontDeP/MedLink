// lib/views/pages/home_page.dart (MODIFICADO PARA USAR O NOVO FAB)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medlink/controllers/home_controller.dart';
// import 'package:medlink/views/pages/nova_consulta_page.dart'; // Não é mais chamado daqui
import 'package:medlink/views/widgets/home/home_header.dart';
import 'package:medlink/views/widgets/home/proxima_consulta_card.dart';
import 'package:medlink/views/widgets/home/home_calendar.dart';
// import 'package:medlink/models/dashboard_data_model.dart'; // Não é mais necessário aqui

// --- IMPORTAÇÃO ADICIONADA ---
import 'package:medlink/views/widgets/home/home_fab_menu.dart'; 

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // --- FUNÇÃO ANTIGA (Modal) REMOVIDA ---
  // void _showFabOptions(BuildContext context, HomeController controller) { ... }
  // --- A FUNÇÃO ACIMA FOI APAGADA ---

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeController(),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 0, // Esconde a AppBar padrão
        ),
        body: Consumer<HomeController>(
          builder: (context, controller, child) {
            return Stack(
              children: [
                // Conteúdo principal (igual ao seu arquivo)
                _buildBodyContent(context, controller),

                // --- INÍCIO DA MODIFICAÇÃO (Regra 2) ---
                // O FAB antigo foi removido e substituído por este widget.
                // Passamos a função de recarregar do controller para o widget.
                HomeFabMenu(
                  onNavigate: controller.fetchDashboardData,
                ),
                // --- FIM DA MODIFICAÇÃO ---
              ],
            );
          },
        ),
        backgroundColor: const Color(0xFF5BBCDC),
      ),
    );
  }

  // O _buildBodyContent permanece exatamente igual ao seu arquivo
  Widget _buildBodyContent(BuildContext context, HomeController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '${controller.errorMessage}',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (controller.dashboardData == null) {
      return const Center(
        child: Text(
          'Nenhum dado encontrado.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Se tudo deu certo, constrói a tela com os novos widgets
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cabeçalho (Avatar e Nome)
            HomeHeader(
              nomePaciente: controller.dashboardData!.nomePaciente,
            ),
            const SizedBox(height: 30),

            // 2. Card da Próxima Consulta
            ProximaConsultaCard(
              proximaConsulta: controller.dashboardData!.proximaConsulta,
            ),
            const SizedBox(height: 30),

            // 3. Calendário (com toda a lógica encapsulada)
            HomeCalendar(
              controller: controller,
            ),
            
            const SizedBox(height: 100), // Espaço para o botão flutuante
          ],
        ),
      ),
    );
  }
}