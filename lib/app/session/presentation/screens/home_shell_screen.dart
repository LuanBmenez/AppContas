import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/core/di/service_locator.dart';
import 'package:paga_o_que_me_deve/core/errors/app_exceptions.dart';
import 'package:paga_o_que_me_deve/core/services/notificacao_local_service.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  late final FinanceRepository _db;
  late final NotificacaoLocalService _notificacaoLocalService;

  @override
  void initState() {
    super.initState();
    _db = getIt<FinanceRepository>();
    _notificacaoLocalService = getIt<NotificacaoLocalService>();

    // Usamos unawaited para não travar a build inicial da tela
    unawaited(_configurarLembretesInteligentes());
  }

  Future<void> _configurarLembretesInteligentes() async {
    try {
      final resumo = await _db.buscarResumoParaNotificacao(DateTime.now());

      await _notificacaoLocalService.agendarResumoFinanceiroDiario(
        totalGastos: resumo.gastos,
        totalReceber: resumo.receber,
        nomesReceber: resumo.nomesReceber,
      );
    } catch (e) {
      final exception = AppException.from(e);
      debugPrint(
        'Falha ao configurar lembretes inteligentes: ${exception.message}',
      );
    }
  }

  /// Descobre em que aba estamos baseado na Rota do GoRouter
  int _obterIndiceAtual(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRoutes.inicioPath)) return 0;
    if (location.startsWith(AppRoutes.gastosPath)) return 1;
    if (location.startsWith(AppRoutes.receberPath)) return 2;
    if (location.startsWith(AppRoutes.guardadoPath)) return 3;
    if (location.startsWith(AppRoutes.perfilPath)) return 4;
    return 0; // Fallback
  }

  String _obterTitulo(int indice) {
    return switch (indice) {
      0 => 'Visão Geral',
      1 => 'Meus Gastos',
      2 => 'A Receber',
      3 => 'Guardado',
      4 => 'Perfil',
      _ => 'AppContas',
    };
  }

  Future<void> _onAdicionar(BuildContext context, int indiceAtual) async {
    if (indiceAtual == 1) {
      // Aba Gastos
      context.push(AppRoutes.novoGastoPath);
    } else if (indiceAtual == 2) {
      // Aba Receber
      context.push(AppRoutes.novoRecebivelPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos o índice apenas uma vez por build
    final indiceAtual = _obterIndiceAtual(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_obterTitulo(indiceAtual)),
        actions:
            indiceAtual ==
                1 // Mostra botões apenas na aba Gastos
            ? <Widget>[
                IconButton(
                  tooltip: 'Orçamentos',
                  onPressed: () => context.push(AppRoutes.orcamentosPath),
                  icon: const Icon(Icons.savings_outlined),
                ),
                IconButton(
                  tooltip: 'Cartões',
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
      body: widget.child,
      floatingActionButton:
          (indiceAtual == 0 || indiceAtual == 3 || indiceAtual == 4)
          ? null
          : FloatingActionButton(
              heroTag: 'home_shell_add_fab',
              onPressed: () => _onAdicionar(context, indiceAtual),
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
          selectedIndex: indiceAtual,
          onDestinationSelected: (index) {
            // Em vez de context.go(), você pode usar navigateTo se implementar o StatefulShellRoute,
            // mas o context.go() funciona perfeitamente.
            if (index == 0) context.go(AppRoutes.inicioPath);
            if (index == 1) context.go(AppRoutes.gastosPath);
            if (index == 2) context.go(AppRoutes.receberPath);
            if (index == 3) context.go(AppRoutes.guardadoPath);
            if (index == 4) context.go(AppRoutes.perfilPath);
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
