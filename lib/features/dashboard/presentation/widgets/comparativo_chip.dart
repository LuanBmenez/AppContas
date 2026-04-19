import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class ComparativoChip extends StatelessWidget {
  const ComparativoChip({
    required this.titulo, required this.percentual, required this.positivoEhBom, super.key,
  });

  final String titulo;
  final double percentual;
  final bool positivoEhBom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const fallbackSemantic = AppSemanticColors(
      success: Color(0xFF0F9D7A),
      successContainer: Color(0xFFE5F6F2),
      warning: Color(0xFFC26A00),
      warningContainer: Color(0xFFFFEED9),
      error: Color(0xFFD64545),
      errorContainer: Color(0xFFFDE8E8),
    );
    final semantic =
        theme.extension<AppSemanticColors>() ?? fallbackSemantic;

    final subiu = percentual >= 0;
    final bom = positivoEhBom ? subiu : !subiu;
    final cor = bom ? semantic.success : semantic.error;
    final icone = subiu
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${percentual.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
