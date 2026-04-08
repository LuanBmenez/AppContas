import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/services.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../features/a_receber/presentation/screens/a_receber_screen.dart';
import '../../features/a_receber/presentation/screens/nova_conta_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/cartoes/presentation/screens/cartoes_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/gastos/presentation/screens/gastos_screen.dart';
import '../../features/gastos/presentation/screens/novo_gasto_screen.dart';
import '../../features/importacao/presentation/screens/importacao_screen.dart';
import '../../features/perfil/presentation/screens/perfil_screen.dart';
import '../session/presentation/screens/home_shell_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static final FinanceRepository _db = DatabaseService();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.inicioPath,
    refreshListenable: GoRouterAuthRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (BuildContext context, GoRouterState state) {
      final bool autenticado = FirebaseAuth.instance.currentUser != null;
      final bool estaNoLogin = state.matchedLocation == '/login';

      if (!autenticado && !estaNoLogin) {
        return '/login';
      }

      if (autenticado && estaNoLogin) {
        return AppRoutes.inicioPath;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.inicioPath,
        name: AppRoutes.inicioName,
        builder: (BuildContext context, GoRouterState state) {
          return HomeShellScreen(
            db: _db,
            currentTab: HomeTab.inicio,
            child: DashboardScreen(db: _db),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.despesasPath,
        name: AppRoutes.despesasName,
        builder: (BuildContext context, GoRouterState state) {
          final DashboardDrillDownFilter? filtroViaQuery =
              AppRoutes.despesasFilterFromQuery(state.uri.queryParameters);
          final DashboardDrillDownFilter? filtroViaExtra =
              state.extra is DashboardDrillDownFilter
              ? state.extra as DashboardDrillDownFilter
              : null;
          final DashboardDrillDownFilter? filtro =
              filtroViaQuery ?? filtroViaExtra;

          return HomeShellScreen(
            db: _db,
            currentTab: HomeTab.despesas,
            child: GastosScreen(
              key: ValueKey<String>(
                filtro == null
                    ? 'despesas_sem_filtro'
                    : 'despesas_${filtro.mesReferencia?.millisecondsSinceEpoch ?? 0}_${filtro.categoriaPadrao?.name ?? ''}_${filtro.categoriaPersonalizadaId ?? ''}_${filtro.tipo?.name ?? ''}',
              ),
              db: _db,
              initialFilter: filtro,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.receberPath,
        name: AppRoutes.receberName,
        builder: (BuildContext context, GoRouterState state) {
          return HomeShellScreen(
            db: _db,
            currentTab: HomeTab.receber,
            child: AReceberScreen(db: _db),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.perfilPath,
        name: AppRoutes.perfilName,
        builder: (BuildContext context, GoRouterState state) {
          return HomeShellScreen(
            db: _db,
            currentTab: HomeTab.perfil,
            child: const PerfilScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.novaDespesaPath,
        name: AppRoutes.novaDespesaName,
        builder: (BuildContext context, GoRouterState state) {
          return NovoGastoScreen(db: _db);
        },
      ),
      GoRoute(
        path: AppRoutes.cartoesPath,
        name: AppRoutes.cartoesName,
        builder: (BuildContext context, GoRouterState state) {
          return CartoesScreen(db: _db);
        },
      ),
      GoRoute(
        path: AppRoutes.importarPath,
        name: AppRoutes.importarName,
        builder: (BuildContext context, GoRouterState state) {
          return ImportacaoScreen(db: _db);
        },
      ),
      GoRoute(
        path: AppRoutes.novoRecebivelPath,
        name: AppRoutes.novoRecebivelName,
        builder: (BuildContext context, GoRouterState state) {
          return NovoRecebivelScreen(db: _db);
        },
      ),
    ],
  );
}

class GoRouterAuthRefreshStream extends ChangeNotifier {
  GoRouterAuthRefreshStream(Stream<User?> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
