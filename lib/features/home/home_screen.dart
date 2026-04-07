import 'package:flutter/material.dart';

import '../../domain/repositories/finance_repository.dart';
import '../../domain/models/models.dart';
import '../../data/services/services.dart';
import '../despesas/despesas.dart';
import '../inicio/inicio.dart';
import '../receber/receber.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FinanceRepository db = DatabaseService();
  int _indiceAtual = 0;
  int _gastosKeyVersion = 0;
  DashboardDrillDownFilter? _dashboardDrillDownFilter;

  List<Widget> get _abas => [
    DashboardScreen(
      db: db,
      onTapSaidas: _abrirDespesasMesAtual,
      onTapReceber: _abrirReceberPendentes,
      onTapSaidasFiltradas: _abrirDespesasComFiltro,
    ),
    MeusGastosScreen(
      key: ValueKey(_gastosKeyVersion),
      db: db,
      initialFilter: _dashboardDrillDownFilter,
    ),
    AReceberScreen(db: db),
  ];

  String get _titulo {
    if (_indiceAtual == 0) return 'Visão Geral';
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
  }

  void _abrirDespesasMesAtual() {
    setState(() {
      _gastosKeyVersion++;
      _dashboardDrillDownFilter = null;
    });
  }

  void _abrirDespesasComFiltro(DashboardDrillDownFilter filter) {
    setState(() {
      _gastosKeyVersion++;
      _indiceAtual = 1;
      _dashboardDrillDownFilter = filter;
    });
  }

  void _abrirReceberPendentes() {
    setState(() {
      _indiceAtual = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: _indiceAtual == 1
            ? <Widget>[
                IconButton(
                  tooltip: 'Cartoes',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartoesCreditoScreen(db: db),
                      ),
                    );
                  },
                  icon: const Icon(Icons.credit_card_outlined),
                ),
                IconButton(
                  tooltip: 'Importar extrato CSV',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImportarExtratoScreen(db: db),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                ),
              ]
            : null,
      ),
      body: _abas[_indiceAtual],
      floatingActionButton: _indiceAtual == 0
          ? null
          : FloatingActionButton(
              onPressed: _onAdicionar,
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (index) {
          setState(() {
            _indiceAtual = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início',
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
