import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'router/app_router.dart';

class PagaOQueMeDeveApp extends StatelessWidget {
  const PagaOQueMeDeveApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    if (home != null) {
      return MaterialApp(
        title: 'Paga o que me deve',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: home,
      );
    }

    return MaterialApp.router(
      title: 'Paga o que me deve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
