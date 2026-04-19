import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/app/app.dart';
import 'package:paga_o_que_me_deve/core/theme/app_theme_controller.dart';
import 'package:provider/provider.dart';

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
