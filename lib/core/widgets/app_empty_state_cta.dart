import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class AppEmptyStateCta extends StatelessWidget {
  const AppEmptyStateCta({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.s12),
            Text(
              title,
              textAlign: TextAlign.center,
              // Usando a tipografia semântica do AppTheme!
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s16),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
