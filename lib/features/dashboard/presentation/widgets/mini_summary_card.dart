import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';

class MiniSummaryCard extends StatelessWidget {
  const MiniSummaryCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
    required this.mostrarValores,
    this.onTap,
  });

  final String titulo;
  final double valor;
  final Color cor;
  final IconData icone;
  final bool mostrarValores;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cor.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icone, size: 20, color: cor),
                ),
                const SizedBox(height: 14),
                Text(
                  titulo,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mostrarValores ? AppFormatters.moeda(valor) : '••••',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toque para ver detalhes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
