import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';

class InsightResumoCard extends StatelessWidget {
  const InsightResumoCard({
    super.key,
    required this.titulo,
    this.categoria,
    required this.valor,
    required this.mostrarValores,
    this.labelUnico = false,
  });

  final String titulo;
  final DashboardCategoriaResumo? categoria;
  final double valor;
  final bool mostrarValores;
  final bool labelUnico;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color cor = categoria?.color ?? theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (labelUnico)
            Text(
              valor.toInt().toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            )
          else ...[
            Row(
              children: [
                if (categoria != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(categoria!.icon, size: 14, color: cor),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                ],
                Expanded(
                  child: Text(
                    categoria?.label ?? 'Sem dados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              mostrarValores ? AppFormatters.moeda(valor) : '••••',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
