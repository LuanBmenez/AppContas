import 'package:flutter/material.dart';

class DashboardExportCard extends StatelessWidget {
  const DashboardExportCard({
    super.key,
    required this.exportandoRelatorio,
    required this.onExportar,
  });

  final bool exportandoRelatorio;
  final VoidCallback onExportar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exportandoRelatorio
                  ? 'Gerando e compartilhando relatório...'
                  : 'Exportar relatório PDF',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: exportandoRelatorio ? null : onExportar,
            child: Text(exportandoRelatorio ? 'Gerando...' : 'Exportar'),
          ),
        ],
      ),
    );
  }
}
