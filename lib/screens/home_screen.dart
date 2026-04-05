import 'package:flutter/material.dart';

import 'a_receber_screen.dart';
import 'dashboard_screen.dart';
import 'meus_gastos_screen.dart';
import 'nova_conta_screen.dart';
import 'novo_gasto_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceAtual = 0;

  List<Widget> get _abas => const [
    DashboardScreen(),
    MeusGastosScreen(),
    AReceberScreen(),
  ];

  String get _titulo {
    if (_indiceAtual == 0) return 'Visao Geral';
    if (_indiceAtual == 1) return 'Meus Gastos';
    return 'A Receber';
  }

  Future<void> _onAdicionar() async {
    if (_indiceAtual == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NovoGastoScreen()),
      );
      return;
    }

    if (_indiceAtual == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NovoRecebivelScreen()),
      );
      return;
    }

    _mostrarMenuDeOpcoes(context);
  }

  void _mostrarMenuDeOpcoes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'O que voce deseja registrar?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.money_off, color: Colors.white),
                ),
                title: const Text('Um novo gasto (Saiu do meu bolso)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NovoGastoScreen()),
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.handshake, color: Colors.white),
                ),
                title: const Text('Uma divida (Alguem me deve)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NovoRecebivelScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _abas[_indiceAtual],
      floatingActionButton: FloatingActionButton(
        onPressed: _onAdicionar,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (index) {
          setState(() => _indiceAtual = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Despesas',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'A Receber',
          ),
        ],
      ),
    );
  }
}
