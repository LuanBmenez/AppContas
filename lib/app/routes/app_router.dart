import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/app/session/presentation/screens/home_shell_screen.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/a_receber/a_receber.dart';
import 'package:paga_o_que_me_deve/features/auth/auth.dart';
import 'package:paga_o_que_me_deve/features/cartoes/cartoes.dart';
import 'package:paga_o_que_me_deve/features/dashboard/dashboard.dart';
import 'package:paga_o_que_me_deve/features/gastos/gastos.dart';
import 'package:paga_o_que_me_deve/features/guardado/guardado.dart';
import 'package:paga_o_que_me_deve/features/importacao/importacao.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/orcamentos.dart';
import 'package:paga_o_que_me_deve/features/perfil/perfil.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/recorrencias.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.inicioPath,
    refreshListenable: GoRouterAuthRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) {
      final autenticado = FirebaseAuth.instance.currentUser != null;
      final estaNoLogin = state.matchedLocation == '/login';

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
        builder: (context, state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.inicioPath,
        name: AppRoutes.inicioName,
        builder: (context, state) {
          return const HomeShellScreen(
            currentTab: HomeTab.inicio,
            child: DashboardScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.gastosPath,
        name: AppRoutes.gastosName,
        builder: (context, state) {
          final filtroViaQuery = AppRoutes.gastosFilterFromQuery(
            state.uri.queryParameters,
          );
          final filtroViaExtra = state.extra is DashboardDrillDownFilter
              ? state.extra! as DashboardDrillDownFilter
              : null;
          final filtro = filtroViaQuery ?? filtroViaExtra;
          return HomeShellScreen(
            currentTab: HomeTab.gastos,
            child: GastosScreen(
              key: ValueKey<String>(
                filtro == null
                    ? 'gastos_sem_filtro'
                    : 'gastos_${filtro.mesReferencia?.millisecondsSinceEpoch ?? 0}_${filtro.categoriaPadrao?.name ?? ''}_${filtro.categoriaPersonalizadaId ?? ''}_${filtro.tipo?.name ?? ''}',
              ),
              initialFilter: filtro,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.receberPath,
        name: AppRoutes.receberName,
        builder: (context, state) {
          return const HomeShellScreen(
            currentTab: HomeTab.receber,
            child: AReceberScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.guardadoPath,
        name: AppRoutes.guardadoName,
        builder: (context, state) {
          return const HomeShellScreen(
            currentTab: HomeTab.guardado,
            child: GuardadoScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.perfilPath,
        name: AppRoutes.perfilName,
        builder: (context, state) {
          return const HomeShellScreen(
            currentTab: HomeTab.perfil,
            child: PerfilScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.recorrenciasPath,
        name: AppRoutes.recorrenciasName,
        builder: (context, state) {
          return const ComprasRecorrentesScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.novoGastoPath,
        name: AppRoutes.novoGastoName,
        builder: (context, state) {
          return const NovoGastoScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.orcamentosPath,
        name: AppRoutes.orcamentosName,
        builder: (context, state) {
          return const OrcamentosScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.cartoesPath,
        name: AppRoutes.cartoesName,
        builder: (context, state) {
          return const CartoesScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.importarPath,
        name: AppRoutes.importarName,
        builder: (context, state) {
          return const ImportacaoScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.novoRecebivelPath,
        name: AppRoutes.novoRecebivelName,
        builder: (context, state) {
          return const NovoRecebivelScreen();
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
