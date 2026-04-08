import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

enum HomeTab { inicio, despesas, receber, perfil }

class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({
    super.key,
    required this.db,
    required this.currentTab,
    required this.child,
  });

  final FinanceRepository db;
  final HomeTab currentTab;
  final Widget child;

  String get _titulo {
    if (currentTab == HomeTab.inicio) return 'Visão Geral';
    if (currentTab == HomeTab.despesas) return 'Meus Gastos';
    if (currentTab == HomeTab.receber) return 'A Receber';
    return 'Perfil';
  }

  int get _indiceAtual => switch (currentTab) {
    HomeTab.inicio => 0,
    HomeTab.despesas => 1,
    HomeTab.receber => 2,
    HomeTab.perfil => 3,
  };

  Future<void> _onAdicionar(BuildContext context) async {
    if (currentTab == HomeTab.despesas) {
      context.push('/despesas/novo');
      return;
    }

    if (currentTab == HomeTab.receber) {
      context.push('/receber/nova');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        actions: currentTab == HomeTab.despesas
            ? <Widget>[
                IconButton(
                  tooltip: 'Cartoes',
                  onPressed: () => context.push('/despesas/cartoes'),
                  icon: const Icon(Icons.credit_card_outlined),
                ),
                IconButton(
                  tooltip: 'Importar extrato CSV',
                  onPressed: () => context.push('/despesas/importar'),
                  icon: const Icon(Icons.upload_file_outlined),
                ),
              ]
            : null,
      ),
      body: child,
      floatingActionButton:
          currentTab == HomeTab.inicio || currentTab == HomeTab.perfil
          ? null
          : FloatingActionButton(
              onPressed: () => _onAdicionar(context),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 70,
          elevation: 4,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            final bool ativo = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
            );
          }),
          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: NavigationBar(
          selectedIndex: _indiceAtual,
          onDestinationSelected: (index) {
            if (index == 0) {
              context.go('/inicio');
              return;
            }
            if (index == 1) {
              context.go('/despesas');
              return;
            }
            if (index == 2) {
              context.go('/receber');
              return;
            }
            context.go('/perfil');
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
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

typedef HomeScreen = HomeShellScreen;
