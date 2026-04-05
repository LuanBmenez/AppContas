import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'a_receber/a_receber_screen.dart';
import 'a_receber/nova_conta_screen.dart';
import 'despesas/meus_gastos_screen.dart';
import 'despesas/novo_gasto_screen.dart';
import 'inicio/dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService db = DatabaseService();
  int _indiceAtual = 0;
  bool _somentePendentes = false;
  int _gastosKeyVersion = 0;

  List<Widget> get _abas => [
    DashboardScreen(
      db: db,
      onTapSaidas: _abrirDespesasMesAtual,
      onTapReceber: _abrirReceberPendentes,
    ),
    MeusGastosScreen(key: ValueKey(_gastosKeyVersion), db: db),
    AReceberScreen(db: db, somentePendentes: _somentePendentes),
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
        MaterialPageRoute(builder: (_) => NovoGastoScreen(db: db)),
      );
      return;
    }

    if (_indiceAtual == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NovoRecebivelScreen(db: db)),
      );
      return;
    }

    _mostrarMenuDeOpcoes(context);
  }

  void _abrirDespesasMesAtual() {
    setState(() {
      _gastosKeyVersion++;
      _indiceAtual = 1;
      _somentePendentes = false;
    });
  }

  void _abrirReceberPendentes() {
    setState(() {
      _indiceAtual = 2;
      _somentePendentes = true;
    });
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
                    MaterialPageRoute(builder: (_) => NovoGastoScreen(db: db)),
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
                      builder: (_) => NovoRecebivelScreen(db: db),
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
          setState(() {
            _indiceAtual = index;
            if (index != 2) {
              _somentePendentes = false;
            }
          });
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
