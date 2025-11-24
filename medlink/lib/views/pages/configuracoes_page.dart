// lib/views/pages/configuracoes_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import necessário

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  bool temaEscuro = false;
  bool contrasteAlto = false;
  bool loginBiometrico = false;
  
  // Instância do Secure Storage para manipulação de tokens
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Função que executa o logout
  Future<void> _logout() async {
    // 1. Apaga os tokens (access e refresh)
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    
    // 2. Navega para a tela de Login ('/') e remove todas as telas anteriores (pilha limpa)
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Preferências do App',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('Tema escuro'),
            value: temaEscuro,
            onChanged: (value) {
              setState(() => temaEscuro = value);
              // Aqui você pode aplicar o tema global
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          SwitchListTile(
            title: const Text('Modo de contraste alto'),
            value: contrasteAlto,
            onChanged: (value) {
              setState(() => contrasteAlto = value);
            },
            secondary: const Icon(Icons.contrast),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Tamanho da fonte'),
            subtitle: const Text('Normal'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // abrir modal para escolher tamanho da fonte
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Idioma'),
            subtitle: const Text('Português (Brasil)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // abrir opções de idioma
            },
          ),

          const Divider(height: 24),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Privacidade e Segurança',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('Login biométrico'),
            value: loginBiometrico,
            onChanged: (value) {
              setState(() => loginBiometrico = value);
            },
            secondary: const Icon(Icons.fingerprint),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Gerenciar permissões'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // abrir tela de permissões
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Política de privacidade'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // abrir link ou PDF da política
            },
          ),

          const Divider(height: 24),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Ajuda e Suporte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Central de ajuda'),
            onTap: () {
              // abrir página de FAQ
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Fale conosco'),
            subtitle: const Text('suporte@medlink.com'),
            onTap: () {
              // abrir email ou chat
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_rate),
            title: const Text('Avaliar o aplicativo'),
            onTap: () {
              // redirecionar para loja
            },
          ),

          const Divider(height: 24),

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
              // abrir modal com nomes e funções
            },
          ),
          
          const Divider(height: 24), // Adiciona um divisor antes do botão de Sair
          
          // NOVO BOTÃO DE SAIR
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _logout, // Chama a função de logout
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}