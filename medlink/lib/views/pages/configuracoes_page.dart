// lib/views/pages/configuracoes_page.dart
import 'package:flutter/material.dart';

class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        centerTitle: true,
        elevation: 2,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ===== Seção 1 - Preferências do App =====
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Preferências do App',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Tamanho da fonte'),
            subtitle: const Text('Normal'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: abrir modal para escolher tamanho da fonte
            },
          ),

          const Divider(height: 24),

          // ===== Seção 2 - Privacidade e Segurança =====
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Privacidade e Segurança',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Política de privacidade'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // TODO: abrir link ou PDF da política
            },
          ),

          const Divider(height: 24),

          // ===== Seção 3 - Ajuda e Suporte =====
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Ajuda e Suporte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Fale conosco'),
            subtitle: const Text('suporte@medlink.com'),
            onTap: () {
              // TODO: abrir email ou chat
            },
          ),

          const Divider(height: 24),

          // ===== Seção 4 - Sobre o MedLink =====
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Sobre o MedLink',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão do app'),
            subtitle: const Text('v1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Créditos e equipe'),
            onTap: () {
              // TODO: abrir modal com nomes e funções
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
