// medlink/lib/views/pages/register.dart (VERSÃO COM LARGURA MÁXIMA)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importe para usar TextInputFormatter
import '../../controllers/register_controller.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _registerController = RegisterController();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  final _cpfMaskFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5BBCDC), // Fundo azul
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          // ===== INÍCIO DA ALTERAÇÃO =====
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500), // Define a largura máxima aqui
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/Logo2.png',
                  height: 100,
                ),
                const SizedBox(height: 20),

                // Título
                const Text(
                  "Cadastrar-se",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                // Campos de input
                _buildTextField("Nome Completo", Icons.person, _nomeController),
                const SizedBox(height: 15),

                _buildTextField(
                  "CPF",
                  Icons.credit_card,
                  _cpfController,
                  hintText: "000.000.000-00",
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cpfMaskFormatter],
                ),
                const SizedBox(height: 15),

                _buildTextField("E-mail", Icons.email, _emailController,
                    hintText: "exemplo@email.com",
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 15),

                _buildTextField(
                  "Telefone",
                  Icons.phone,
                  _telefoneController,
                  hintText: "(00) 00000-0000",
                  keyboardType: TextInputType.number,
                  inputFormatters: [_phoneMaskFormatter],
                ),
                const SizedBox(height: 15),

                // Senha com ícone de olho
                _buildPasswordField("Senha", _senhaController, _senhaVisivel,
                    () => setState(() => _senhaVisivel = !_senhaVisivel)),
                const SizedBox(height: 15),

                _buildPasswordField(
                    "Confirmar Senha",
                    _confirmarSenhaController,
                    _confirmarSenhaVisivel,
                    () => setState(
                        () => _confirmarSenhaVisivel = !_confirmarSenhaVisivel)),
                const SizedBox(height: 30),

                // Botão Cadastrar-se
                _buildButton("Cadastrar-se", const Color(0xFF42A01C), () {
                  _registerController.register(
                    context,
                    // Adapte os nomes dos parâmetros se forem diferentes no seu controller
                    username: _nomeController.text,
                    cpf: _cpfController.text,
                    email: _emailController.text,
                    telefone: _telefoneController.text,
                    password: _senhaController.text,
                    confirmarSenha: _confirmarSenhaController.text,
                  );
                }),
                const SizedBox(height: 15),

                const Text("OU", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 15),

                // Botão Entrar
                _buildButton("Entrar", const Color(0xFF1D80A1), () {
                  Navigator.pushReplacementNamed(context, '/');
                }),
              ],
            ),
          ),
          // ===== FIM DA ALTERAÇÃO =====
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool obscureText = false,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5BBCDC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5BBCDC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1D80A1), width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller,
      bool isVisible, VoidCallback toggleVisibility) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: toggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5BBCDC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5BBCDC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1D80A1), width: 2),
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return color.withOpacity(0.7);
              } else if (states.contains(WidgetState.hovered)) {
                return color.withOpacity(0.85);
              }
              return color; // cor padrão
            },
          ),
          minimumSize: WidgetStateProperty.resolveWith<Size>(
            (_) => const Size(double.infinity, 50),
          ),
          shape: WidgetStateProperty.resolveWith<OutlinedBorder>(
            (_) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}