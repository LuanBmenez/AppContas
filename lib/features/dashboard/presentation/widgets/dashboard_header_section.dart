import 'package:flutter/material.dart';

class DashboardHeaderSection extends StatelessWidget {
  const DashboardHeaderSection({
    super.key,
    required this.tituloPeriodo,
    required this.insight,
  });

  final String tituloPeriodo;
  final String insight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo financeiro',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tituloPeriodo,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (insight.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            insight,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}
