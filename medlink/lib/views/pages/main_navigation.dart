// lib/views/pages/main_navigation.dart
import 'package:flutter/material.dart';

// Importa as telas principais
import 'home_page.dart';
// import 'notificacoes_page.dart'; // <<< REMOVER ESTA IMPORTAÇÃO
import 'perfil_page.dart';
import 'configuracoes_page.dart';

// Importa o widget da navbar
import '../widgets/bottom_navbar.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // O índice 1 (Notificações) foi removido, agora o Perfil é o índice 1 e Configurações é o 2.
  int _selectedIndex = 0; 

  // Lista das páginas principais (NotificacoesPage removida)
  final List<Widget> _pages = const [
    HomePage(),
    // NotificacoesPage(), // <<< REMOVER ESTA LINHA
    PerfilPage(),
    ConfiguracoesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavbar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}