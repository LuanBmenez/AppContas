import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';

class BarraCategoriaLinha extends StatelessWidget {
  const BarraCategoriaLinha({
    super.key,
    required this.categoria,
    required this.total,
    required this.mostrarValores,
    this.onTap,
  });

  final DashboardCategoriaResumo categoria;
  final double total;
  final bool mostrarValores;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double percentual = total <= 0 ? 0 : categoria.valor / total;
    final String percentualTexto = '${(percentual * 100).toStringAsFixed(1)}%';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: categoria.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoria.icon,
                      size: 16,
                      color: categoria.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(
                      categoria.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    percentualTexto,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    mostrarValores
                        ? AppFormatters.moeda(categoria.valor)
                        : '••••',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: percentual,
                  backgroundColor: categoria.color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(categoria.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
