import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/barra_categoria_linha.dart';

class CategoriasBarrasCard extends StatelessWidget {
  const CategoriasBarrasCard({
    super.key,
    required this.total,
    required this.periodo,
    required this.data,
    required this.mostrarValores,
    this.onTapCategoria,
  });

  final double total;
  final String periodo;
  final List<DashboardCategoriaResumo> data;
  final bool mostrarValores;
  final ValueChanged<DashboardCategoriaResumo>? onTapCategoria;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<DashboardCategoriaResumo> barras = data.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.05),
            theme.colorScheme.secondary.withValues(alpha: 0.025),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      mostrarValores ? AppFormatters.moeda(total) : '••••',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${data.length} categorias',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s18),
          ...barras.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s14),
              child: BarraCategoriaLinha(
                categoria: entry,
                total: total,
                mostrarValores: mostrarValores,
                onTap: onTapCategoria == null
                    ? null
                    : () => onTapCategoria!(entry),
              ),
            ),
          ),
          if (data.length > barras.length)
            Text(
              '+ ${data.length - barras.length} categorias adicionais',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
