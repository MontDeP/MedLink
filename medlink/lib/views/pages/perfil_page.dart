// lib/views/pages/perfil_page.dart
import 'package:flutter/material.dart';

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // altura menor
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: Colors.grey[400]),
    );

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 195, 247, 250),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            // ---------------- Parte superior (quadrado + foto + info) ----------------
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  height: 165,
                  color: Colors.blue,
                ),
                Positioned(
                  bottom: -75,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 75,
                        backgroundImage: NetworkImage(
                            'https://via.placeholder.com/150'),
                        backgroundColor: Colors.grey[300],
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.edit, size: 20, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 85),
            const Text(
              'Nome do Usuário',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // ---------------- Linha de informações (agora inputs editáveis) ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoInputItem('Altura', Icons.height, '160 cm'),
                  _infoInputItem('Peso', Icons.monitor_weight, '65 kg'),
                  _infoInputItem('Idade', Icons.cake, '25 anos'),
                  _infoInputItem('Sangue', Icons.bloodtype, 'O-'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---------------- Informações Pessoais ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informações Pessoais:',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _inputField('Nome Completo', inputDecoration),
                  const SizedBox(height: 12),
                  _inputField('CPF', inputDecoration),
                  const SizedBox(height: 12),
                  _inputField('Email', inputDecoration),
                  const SizedBox(height: 12),
                  _inputField('Telefone', inputDecoration),
                  const SizedBox(height: 24),

                  // ---------------- Endereço ----------------
                  const Text(
                    'Endereço:',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _inputField('Bairro', inputDecoration),
                  const SizedBox(height: 12),
                  _inputField('Quadra', inputDecoration),
                  const SizedBox(height: 12),
                  _inputField('Av/Rua', inputDecoration),
                  const SizedBox(height: 12),
                  _inputField('Número', inputDecoration),
                  const SizedBox(height: 24),

                  // ---------------- Informações Adicionais ----------------
                  const Text(
                    'Informações Adicionais:',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 150,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const SingleChildScrollView(
                      child: TextField(
                        maxLines: null,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Digite informações adicionais...',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------------- Botão Atualizar Perfil ----------------
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: ação de atualizar perfil
                      },
                      child: const Text('Atualizar Perfil'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Widget para cada info item editável ----------------
  Widget _infoInputItem(String title, IconData icon, String initialValue) {
    final controller = TextEditingController(text: initialValue);

    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Círculo com ícone
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            // Input sobreposto (retângulo)
            Positioned(
              bottom: -12,
              child: SizedBox(
                width: 70,
                height: 24,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inputField(String label, InputDecoration decoration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: TextField(
            decoration: decoration,
          ),
        ),
      ],
    );
  }
}