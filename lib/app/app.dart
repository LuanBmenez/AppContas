import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import '../features/home/home_screen.dart';

class PagaOQueMeDeveApp extends StatelessWidget {
  const PagaOQueMeDeveApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paga o que me deve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home ?? const HomeScreen(),
    );
  }
}
