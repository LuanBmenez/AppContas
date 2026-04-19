import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

enum HomeTab { inicio, gastos, receber, guardado, perfil }

class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({
    required this.db, required this.currentTab, required this.child, super.key,
  });

  final FinanceRepository db;
  final HomeTab currentTab;
  final Widget child;

  String get _titulo {
    if (currentTab == HomeTab.inicio) return 'Visão Geral';
    if (currentTab == HomeTab.gastos) return 'Meus Gastos';
    if (currentTab == HomeTab.receber) return 'A Receber';
    if (currentTab == HomeTab.guardado) return 'Guardado';
    return 'Perfil';
  }

  int get _indiceAtual => switch (currentTab) {
    HomeTab.inicio => 0,
    HomeTab.gastos => 1,
    HomeTab.receber => 2,
    HomeTab.guardado => 3,
    HomeTab.perfil => 4,
  };

  Future<void> _onAdicionar(BuildContext context) async {
    if (currentTab == HomeTab.gastos) {
      context.push(AppRoutes.novoGastoPath);
      return;
    }

    if (currentTab == HomeTab.receber) {
      context.push(AppRoutes.novoRecebivelPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        actions: currentTab == HomeTab.gastos
            ? <Widget>[
                IconButton(
                  tooltip: 'Orçamentos',
                  onPressed: () => context.push(AppRoutes.orcamentosPath),
                  icon: const Icon(Icons.savings_outlined),
                ),
                IconButton(
                  tooltip: 'Cartoes',
                  onPressed: () => context.push(AppRoutes.cartoesPath),
                  icon: const Icon(Icons.credit_card_outlined),
                ),
                IconButton(
                  tooltip: 'Importar extrato CSV',
                  onPressed: () => context.push(AppRoutes.importarPath),
                  icon: const Icon(Icons.upload_file_outlined),
                ),
              ]
            : null,
      ),
      body: child,
      floatingActionButton:
          currentTab == HomeTab.inicio ||
                  currentTab == HomeTab.guardado ||
                  currentTab == HomeTab.perfil
              ? null
              : FloatingActionButton(
                  heroTag: 'home_shell_add_fab',
                  onPressed: () => _onAdicionar(context),
                  child: const Icon(Icons.add),
                ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 70,
          elevation: 4,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            final ativo = states.contains(WidgetState.selected);
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
              context.go(AppRoutes.inicioPath);
              return;
            }
            if (index == 1) {
              context.go(AppRoutes.gastosPath);
              return;
            }
            if (index == 2) {
              context.go(AppRoutes.receberPath);
              return;
            }
            if (index == 3) {
              context.go(AppRoutes.guardadoPath);
              return;
            }
            context.go(AppRoutes.perfilPath);
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
              label: 'Gastos',
            ),
            NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(Icons.handshake),
              label: 'A Receber',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings),
              label: 'Guardado',
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
