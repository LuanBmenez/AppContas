import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Como configurámos o CardTheme no app_theme.dart,
    // não precisamos de repetir o shape, elevation ou color aqui!
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: child,
      ),
    );
  }
}
