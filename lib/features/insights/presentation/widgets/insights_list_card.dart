import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/features/insights/domain/models/insight_item.dart';

class InsightsListCard extends StatelessWidget {
  const InsightsListCard({required this.insights, super.key});

  final List<InsightItem> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insights',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Text(
              'Resumo automático do que merece atenção agora.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (insights.isEmpty)
              Text(
                'Sem alertas relevantes por enquanto.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: insights.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                    child: _InsightRow(item: item),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.item});

  final InsightItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = switch (item.nivel) {
      InsightNivel.alerta => theme.colorScheme.error,
      InsightNivel.atencao => const Color(0xFFC26A00),
      InsightNivel.info => theme.colorScheme.primary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icone, size: 18, color: cor),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              item.mensagem,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
