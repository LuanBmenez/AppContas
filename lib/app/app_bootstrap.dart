import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme_controller.dart';
import 'app.dart';

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppThemeController(),
      child: const _AppWithTheme(),
    );
  }
}

class _AppWithTheme extends StatelessWidget {
  const _AppWithTheme();

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<AppThemeController>(context);
    return PagaOQueMeDeveApp(themeMode: themeController.themeMode);
  }
}
