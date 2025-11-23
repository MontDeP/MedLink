// lib/views/widgets/home/home_fab_menu.dart (CORRIGIDO E REORDENADO)
import 'package:flutter/material.dart';

class HomeFabMenu extends StatefulWidget {
  final VoidCallback onNavigate; 

  const HomeFabMenu({super.key, required this.onNavigate});

  @override
  State<HomeFabMenu> createState() => _HomeFabMenuState();
}

class _HomeFabMenuState extends State<HomeFabMenu> {
  bool _isFabMenuOpen = false;

  void _toggleFabMenu() {
    setState(() {
      _isFabMenuOpen = !_isFabMenuOpen;
    });
  }

  void _navigateTo(BuildContext context, String routeName) {
    _toggleFabMenu(); 
    // Navega e usa o .then para garantir que o Dashboard recarregue ao voltar
    Navigator.pushNamed(context, routeName).then((_) {
      widget.onNavigate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabMenuOpen) ...[
            
            // 1. CANCELAR (TOP)
            _buildMiniFab(
              icon: Icons.cancel_outlined, // Novo Ícone de cancelamento
              label: 'Cancelar Consulta',
              onPressed: () => _navigateTo(context, '/cancelar-consulta'), // Nova rota
            ),
            const SizedBox(height: 12),

            // 2. REMARCAR (MIDDLE)
            _buildMiniFab(
              icon: Icons.edit_calendar,
              label: 'Remarcar',
              onPressed: () => _navigateTo(context, '/remarcar-consulta'),
            ),
            const SizedBox(height: 12),
            
            // 3. NOVA CONSULTA (BOTTOM)
            _buildMiniFab(
              icon: Icons.calendar_month, 
              label: 'Nova Consulta',
              onPressed: () => _navigateTo(context, '/nova-consulta'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            onPressed: _toggleFabMenu,
            backgroundColor: _isFabMenuOpen ? Colors.redAccent : const Color(0xFF317714),
            child: Icon(
              _isFabMenuOpen ? Icons.close : Icons.add,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniFab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // O "balãozinho" com o texto agora é clicável
        GestureDetector(
          onTap: onPressed, // Adiciona o clique aqui
          // Isso faz o clique "atravessar" o container transparente
          behavior: HitTestBehavior.opaque, 
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(width: 10),
        
        // O botão (FAB pequeno)
        FloatingActionButton.small(
          onPressed: onPressed, // E o clique continua aqui
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0066CC),
          heroTag: label, 
          child: Icon(icon),
        ),
      ],
    );
  }
}