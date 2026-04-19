import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:paga_o_que_me_deve/app/routes/app_router.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class PagaOQueMeDeveApp extends StatelessWidget {
  const PagaOQueMeDeveApp({super.key, this.home, this.themeMode});

  final Widget? home;
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context) {
    if (home != null) {
      return MaterialApp(
        title: 'Paga o que me deve',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode ?? ThemeMode.system,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      );
    }

    return MaterialApp.router(
      title: 'Paga o que me deve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode ?? ThemeMode.system,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: AppRouter.router,
    );
  }
}
