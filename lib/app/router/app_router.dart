import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/services.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../features/auth/login_screen.dart';
import '../../features/despesas/despesas.dart';
import '../../features/home/home_screen.dart';
import '../../features/inicio/inicio.dart';
import '../../features/receber/receber.dart';
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
          return HomeScreen(
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

          return HomeScreen(
            db: _db,
            currentTab: HomeTab.despesas,
            child: MeusGastosScreen(
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
          return HomeScreen(
            db: _db,
            currentTab: HomeTab.receber,
            child: AReceberScreen(db: _db),
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
          return CartoesCreditoScreen(db: _db);
        },
      ),
      GoRoute(
        path: AppRoutes.importarPath,
        name: AppRoutes.importarName,
        builder: (BuildContext context, GoRouterState state) {
          return ImportarExtratoScreen(db: _db);
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
