// medlink/lib/main.dart (CORRIGIDO)

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
// IMPORTAÇÃO NECESSÁRIA PARA LOCALIZAÇÃO:
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:medlink/views/pages/home_page.dart';
import 'package:medlink/views/pages/main_navigation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// Views
import 'views/pages/login.dart';
import 'views/pages/register.dart';
import 'views/pages/dashboard_page.dart'; // Presumo que seja SecretaryDashboard
import 'views/pages/admin.dart';
import 'views/pages/admin_edit_user_page.dart';
import 'views/pages/medico_dashboard_page.dart';
import 'views/pages/medico_agenda_page.dart';
import 'views/pages/reset_password_page.dart';
import 'package:medlink/views/pages/create_password_page.dart';
import 'views/pages/super_admin_dashboard_page.dart';
import 'package:medlink/views/pages/nova_consulta_page.dart';
import 'package:medlink/views/pages/remarcar_consulta_page.dart';
import 'package:medlink/views/pages/cancelar_consulta_page.dart';

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

      // Adiciona os delegados de localização.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Define os idiomas suportados.
      supportedLocales: const [
        Locale('pt', 'BR'), // Português (Brasil)
        // Locale('en', 'US'), // Você pode adicionar inglês se quiser
      ],
      // Define o idioma padrão do app
      locale: const Locale('pt', 'BR'),
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

        // Rota simples: /super-admin/dashboard
        if (settings.name == '/super-admin/dashboard') {
          return GetPageRoute(
            settings: settings,
            page: () => const SuperAdminDashboardPage(),
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

        // Rota para a página de Nova Consulta
        if (settings.name == '/nova-consulta') {
          return GetPageRoute(
            settings: settings,
            page: () => const NovaConsultaPage(),
            transition: Transition.rightToLeft,
          );
        }

        // Rota para a página de Remarcar Consulta
        if (settings.name == '/remarcar-consulta') {
          return GetPageRoute(
            settings: settings,
            page: () => const RemarcarConsultaPage(),
            transition: Transition.rightToLeft,
          );
        }
        
        // 👇 NOVA ROTA PARA CANCELAR CONSULTA 👇
        if (settings.name == '/cancelar-consulta') {
          return GetPageRoute(
            settings: settings,
            page: () => const CancelarConsultaPage(),
            transition: Transition.rightToLeft,
          );
        }

        // Rota para /reset-password?uid=...&token=...
        if (settings.name != null &&
            settings.name!.startsWith('/reset-password')) {
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
        if (settings.name != null &&
            settings.name!.startsWith('/criar-senha')) {
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
        print(
          "Aviso: Rota '${settings.name}' não encontrada. Redirecionando para Login.",
        );
        return GetPageRoute(settings: settings, page: () => const LoginPage());
      },
    );
  }
}
