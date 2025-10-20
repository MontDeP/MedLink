// lib/views/widgets/medico_app_bar.dart

import 'package:flutter/material.dart';

class MedicoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String activePage; // "Dashboard" ou "Agenda"

  const MedicoAppBar({super.key, required this.activePage});

  static const Color primaryBlue = Color(0xFF5BBCDC);
  static const Color hoverColor = Color(0xFF4AA0C9);

  @override
  Widget build(BuildContext context) {
    // Função para definir a cor do texto do menu ativo
    Color menuTextColor(String menu) {
      return activePage == menu ? Colors.yellowAccent : Colors.white;
    }

    return AppBar(
      backgroundColor: primaryBlue,
      toolbarHeight: 60,
      automaticallyImplyLeading: false, // Remove o botão de "voltar"
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Image.asset('assets/images/Logo2.png', height: 40),

          // Menu de Navegação Simplificado
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  // Só navega se não estiver na página atual
                  if (activePage != "Dashboard") {
                    Navigator.pushReplacementNamed(context, "/doctor/dashboard");
                  }
                },
                child: Text(
                  "Dashboard",
                  style: TextStyle(color: menuTextColor("Dashboard")),
                ),
              ),
              const SizedBox(width: 24),
              TextButton(
                onPressed: () {
                  // Só navega se não estiver na página atual
                  if (activePage != "Agenda") {
                    Navigator.pushReplacementNamed(context, "/doctor/agenda");
                  }
                },
                child: Text(
                  "Agenda",
                  style: TextStyle(color: menuTextColor("Agenda")),
                ),
              ),
            ],
          ),

          // Ícones de Ação e Logout
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: primaryBlue),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text("Sair", style: TextStyle(color: Colors.white)),
                style: ButtonStyle(
                  overlayColor: MaterialStateProperty.all(hoverColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60.0);
}