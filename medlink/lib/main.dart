// medlink/lib/main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:medlink/views/pages/home_page.dart';
import 'package:medlink/views/pages/main_navigation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// Views
import 'views/pages/login.dart';
import 'views/pages/register.dart';
import 'views/pages/dashboard_page.dart';
import 'views/pages/admin.dart';
import 'views/pages/admin_edit_user_page.dart';
import 'views/pages/medico_dashboard_page.dart';
import 'views/pages/medico_agenda_page.dart';
import 'views/pages/reset_password_page.dart';
import 'package:medlink/views/pages/create_password_page.dart';

// Controllers
import 'controllers/paciente_controller.dart';

void main() async {
  usePathUrlStrategy();
  // Garante que o Flutter está inicializado antes de qualquer outra coisa
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa a formatação de datas para o português do Brasil
  await initializeDateFormatting('pt_BR', null);

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PacienteController())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedLink',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',

      // Usando onGenerateRoute para ter controle sobre rotas dinâmicas
      onGenerateRoute: (settings) {
        // Rota simples: /
        if (settings.name == '/') {
          return GetPageRoute(
            settings: settings,
            page: () => const LoginPage(),
          );
        }

        // Rota simples: /register
        if (settings.name == '/register') {
          return GetPageRoute(
            settings: settings,
            page: () => const RegisterPage(),
          );
        }

        // Rota simples: /secretary/dashboard
        if (settings.name == '/secretary/dashboard') {
          return GetPageRoute(
            settings: settings,
            page: () => const SecretaryDashboard(),
          );
        }

        // Rota simples: /admin/dashboard
        if (settings.name == '/admin/dashboard') {
          return GetPageRoute(
            settings: settings,
            page: () => const AdminDashboard(),
          );
        }

        // Rota simples: /doctor/dashboard
        if (settings.name == '/doctor/dashboard') {
          return GetPageRoute(
            settings: settings,
            page: () => const MedicoDashboardPage(),
          );
        }

        // Rota simples: /doctor/agenda
        if (settings.name == '/doctor/agenda') {
          return GetPageRoute(
            settings: settings,
            page: () => const MedicoAgendaPage(),
          );
        }

        // Rota para /user/dashboard
        if (settings.name == '/user/dashboard') {
          return GetPageRoute(
            settings: settings,
            page: () => const MainNavigation(),
          );
        }
        
        // Rota para /admin/edit-user (que você já tinha)
        if (settings.name == '/admin/edit-user') {
          final userId = settings.arguments as String;
          return GetPageRoute(
            settings: settings,
            page: () => AdminEditUserPage(userId: userId),
          );
        }
      
        // Rota para /reset-password?uid=...&token=...
        if (settings.name != null && settings.name!.startsWith('/reset-password')) {
          final uri = Uri.parse(settings.name!);

          // Verifica se o caminho base é /reset-password
          if (uri.path == '/reset-password') {
            
            // Pega os parâmetros da query (o que vem depois do '?')
            final uid = uri.queryParameters['uid'];
            final token = uri.queryParameters['token'];

            // Se encontrou os dois, navega para a página
            if (uid != null && token != null) {
              return GetPageRoute(
                settings: settings,
                page: () => ResetPasswordPage(uid: uid, token: token),
              );
            }
          }
        }
        
        // Rota para /criar-senha?uid=...&token=...
        if (settings.name != null && settings.name!.startsWith('/criar-senha')) {
          final uri = Uri.parse(settings.name!);

          // Verifica se o caminho base é /criar-senha
          if (uri.path == '/criar-senha') {
            
            // Pega os parâmetros da query (o que vem depois do '?')
            final uid = uri.queryParameters['uid'];
            final token = uri.queryParameters['token'];

            // Se encontrou os dois, navega para a página
            if (uid != null && token != null) {
              return GetPageRoute(
                settings: settings,
                // Chama a nova página que você já importou
                page: () => CreatePasswordPage(uid: uid, token: token),
              );
            }
          }
        }

        // Se nenhuma rota bater, retorna para a página de Login
        return GetPageRoute(
          settings: settings,
          page: () => const LoginPage(),
        );
      },
    );
  }
}