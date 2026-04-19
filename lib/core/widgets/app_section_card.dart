import 'package:flutter/material.dart';

import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: child,
      ),
    );
  }
}
