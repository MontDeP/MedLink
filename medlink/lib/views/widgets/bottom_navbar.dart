// lib/views/widgets/bottom_navbar.dart
import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed, // Mantém a distribuição uniforme
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF0066CC), 
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      selectedFontSize: 13,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        // Item de Notificações Removido
        // BottomNavigationBarItem( 
        //   icon: Icon(Icons.notifications_none),
        //   activeIcon: Icon(Icons.notifications),
        //   label: 'Notificações',
        // ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Configurações',
        ),
      ],
    );
  }
}