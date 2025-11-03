// lib/views/pages/configuracoes_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medlink/services/api_service.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  final _api = ApiService();

  // Site (público)
  String? _appVersion;
  String? _contactEmail;
  String? _privacyUrl;
  String? _privacyMarkdown;
  String? _credits;

  // User (autenticado)
  String _fontSize = 'normal'; // small | normal | large
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final site = await _api.getSiteSettings();
      final me = await _api.getMySettings(); // requer token salvo no ApiService

      setState(() {
        _appVersion      = site?['app_version'] ?? 'v1.0.0';
        _contactEmail    = site?['contact_email'] ?? 'suporte@medlink.com';
        _privacyUrl      = site?['privacy_policy_url'];
        _privacyMarkdown = site?['privacy_policy_markdown'];
        _credits         = site?['credits'] ?? 'Equipe MedLink';

        _fontSize        = (me?['font_size'] ?? 'normal').toString();
        _loading         = false;
      });
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao carregar configurações')),
        );
      }
    }
  }

  String _fontSizeLabel(String v) {
    switch (v) {
      case 'small':  return 'Pequena';
      case 'normal': return 'Normal';
      case 'large':  return 'Grande';
      default:       return v;
    }
  }

  Future<void> _pickFontSize() async {
    const options = ['small', 'normal', 'large'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final label = _fontSizeLabel(opt);
            return ListTile(
              title: Text(label),
              trailing: _fontSize == opt ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, opt),
            );
          }).toList(),
        ),
      ),
    );

    if (selected == null || selected == _fontSize) return;

    final ok = await _api.updateMyFontSize(selected);
    if (!mounted) return;

    if (ok) {
      setState(() => _fontSize = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tamanho da fonte atualizado')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a preferência')),
      );
    }
  }

  Future<void> _openPrivacy() async {
    // 1) prioriza URL, se configurada
    if (_privacyUrl != null && _privacyUrl!.isNotEmpty) {
      final uri = Uri.parse(_privacyUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // 2) se não houver URL, exibe o texto/markdown embutido
    if (_privacyMarkdown != null && _privacyMarkdown!.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Política de privacidade'),
          content: SingleChildScrollView(child: Text(_privacyMarkdown!)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Política de privacidade indisponível')),
    );
  }

  Future<void> _contactSupport() async {
    final email = _contactEmail ?? 'suporte@medlink.com';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: Uri.encodeFull('subject=Suporte MedLink&body=Olá, preciso de ajuda com...'),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o e-mail ($email)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
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
                subtitle: Text(_fontSizeLabel(_fontSize)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickFontSize,
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
                onTap: _openPrivacy,
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
                subtitle: Text(_contactEmail ?? 'suporte@medlink.com'),
                onTap: _contactSupport,
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
                subtitle: Text(_appVersion ?? 'v1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Créditos e equipe'),
                subtitle: Text(_credits ?? 'Equipe MedLink'),
                onTap: () {
                  if (_credits == null || _credits!.isEmpty) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Créditos e equipe'),
                      content: SingleChildScrollView(child: Text(_credits!)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        centerTitle: true,
        elevation: 2,
      ),
      body: body,
    );
  }
}
