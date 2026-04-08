import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/app/session/presentation/screens/home_shell_screen.dart';
import 'package:paga_o_que_me_deve/data/services/services.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/a_receber/a_receber.dart';
import 'package:paga_o_que_me_deve/features/auth/auth.dart';
import 'package:paga_o_que_me_deve/features/cartoes/cartoes.dart';
import 'package:paga_o_que_me_deve/features/dashboard/dashboard.dart';
import 'package:paga_o_que_me_deve/features/gastos/gastos.dart';
import 'package:paga_o_que_me_deve/features/importacao/importacao.dart';
import 'package:paga_o_que_me_deve/features/perfil/perfil.dart';

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
        path: AppRoutes.gastosPath,
        name: AppRoutes.gastosName,
        builder: (BuildContext context, GoRouterState state) {
          final DashboardDrillDownFilter? filtroViaQuery =
              AppRoutes.gastosFilterFromQuery(state.uri.queryParameters);
          final DashboardDrillDownFilter? filtroViaExtra =
              state.extra is DashboardDrillDownFilter
              ? state.extra as DashboardDrillDownFilter
              : null;
          final DashboardDrillDownFilter? filtro =
              filtroViaQuery ?? filtroViaExtra;

          return HomeShellScreen(
            db: _db,
            currentTab: HomeTab.gastos,
            child: GastosScreen(
              key: ValueKey<String>(
                filtro == null
                    ? 'gastos_sem_filtro'
                    : 'gastos_${filtro.mesReferencia?.millisecondsSinceEpoch ?? 0}_${filtro.categoriaPadrao?.name ?? ''}_${filtro.categoriaPersonalizadaId ?? ''}_${filtro.tipo?.name ?? ''}',
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
        path: AppRoutes.novoGastoPath,
        name: AppRoutes.novoGastoName,
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
