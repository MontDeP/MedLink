import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medlink/views/pages/forgot_password_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../controllers/login_controller.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final LoginController _loginController = LoginController();
  final _cpfMaskFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _obscurePassword = true;
  bool _isLoading = false;

  // ---- Lógica de login atualizada ----
  void _onLoginPressed() async {
    final cpf = _cpfController.text;
    final senha = _senhaController.text;
    print("Tentando login com CPF: $cpf e Senha: $senha");

    if (!_loginController.validarCPF(cpf)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("CPF inválido")));
      return;
    }

    setState(() => _isLoading = true);

    final loginData = await _loginController.login(cpf, senha);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (loginData != null) {
      final accessToken = loginData['access_token'];
      final userType = loginData['user_type'];

      // Salva o token com segurança
      const storage = FlutterSecureStorage();
      await storage.write(key: 'access_token', value: accessToken);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login realizado com sucesso!")),
      );

      // Redirecionamento conforme tipo de usuário
      switch (userType) {
        case 'SECRETARIA':
          Navigator.pushReplacementNamed(context, '/secretary/dashboard');
          break;
        case 'MEDICO':
          Navigator.pushReplacementNamed(context, '/doctor/dashboard');
          break;
        case 'ADMIN':
          Navigator.pushReplacementNamed(context, '/admin/dashboard');
          break;
        case 'PACIENTE':
          Navigator.pushReplacementNamed(context, '/user/dashboard');
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tipo de usuário desconhecido!")),
          );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuário ou senha incorretos")),
      );
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF5BBCDC),
    body: Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 80,
                    child: Image.asset(
                      'assets/images/Logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, size: 80);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Realizar Login",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("CPF:"),
                  const SizedBox(height: 8),
                  // ===== INÍCIO DA CORREÇÃO =====
                  TextField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cpfMaskFormatter],
                    // A 'decoration' foi movida para DENTRO do TextField
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.badge),
                      hintText: "000.000.000-00",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF5BBCDC),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  // ===== FIM DA CORREÇÃO =====
                  const SizedBox(height: 16),
                  const Text("Senha:"),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _senhaController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock),
                        hintText: "********",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF5BBCDC),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                         Get.to(() => ForgotPasswordPage());
                        },
                        child: const Text("Esqueci minha senha"),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _onLoginPressed,
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.hovered)) {
                                return const Color(0xFF166580);
                              }
                              return const Color(0xFF1D80A1);
                            }),
                        foregroundColor: WidgetStateProperty.all<Color>(
                          Colors.white,
                        ),
                        padding: WidgetStateProperty.all<EdgeInsets>(
                          const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 14,
                          ),
                        ),
                        shape: WidgetStateProperty.all<OutlinedBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        textStyle: WidgetStateProperty.all<TextStyle>(
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text("Entrar"),
                    ),
                    const SizedBox(height: 16),
                    const Center(child: Text("OU")),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.hovered)) {
                                return const Color(0xFF317714);
                              }
                              return const Color(0xFF42A01C);
                            }),
                        foregroundColor: WidgetStateProperty.all<Color>(
                          Colors.white,
                        ),
                        padding: WidgetStateProperty.all<EdgeInsets>(
                          const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 14,
                          ),
                        ),
                        shape: WidgetStateProperty.all<OutlinedBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        textStyle: WidgetStateProperty.all<TextStyle>(
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      child: const Text("Cadastrar-se"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
