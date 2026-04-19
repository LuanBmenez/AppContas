import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/domain/models/orcamento_categoria.dart';

class OrcamentoCategoriaProgressItem extends StatelessWidget {
  const OrcamentoCategoriaProgressItem({
    required this.resumo, super.key,
    this.onTap,
    this.onDelete,
    this.compacto = false,
  });

  final OrcamentoCategoriaResumo resumo;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool compacto;

  Color _statusColor(ThemeData theme) {
    switch (resumo.status) {
      case OrcamentoCategoriaStatus.normal:
        return theme.extension<AppSemanticColors>()?.success ??
            const Color(0xFF0F9D7A);
      case OrcamentoCategoriaStatus.alerta:
        return theme.extension<AppSemanticColors>()?.warning ??
            const Color(0xFFC26A00);
      case OrcamentoCategoriaStatus.estourado:
        return theme.extension<AppSemanticColors>()?.error ??
            const Color(0xFFD64545);
    }
  }

  String _statusLabel() {
    switch (resumo.status) {
      case OrcamentoCategoriaStatus.normal:
        return 'Normal';
      case OrcamentoCategoriaStatus.alerta:
        return 'Atenção';
      case OrcamentoCategoriaStatus.estourado:
        return 'Estourado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);
    final progress = resumo.percentualUtilizado.clamp(0, 1).toDouble();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: compacto ? 14 : 16,
                    backgroundColor: resumo.orcamento.categoriaPadrao.color
                        .withValues(alpha: 0.14),
                    child: Icon(
                      resumo.orcamento.categoriaPadrao.icon,
                      size: compacto ? 16 : 18,
                      color: resumo.orcamento.categoriaPadrao.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(
                      resumo.orcamento.categoriaPadrao.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: AppSpacing.s4),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Excluir orçamento',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s10),
              LinearProgressIndicator(
                value: progress,
                minHeight: compacto ? 6 : 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s12,
                runSpacing: AppSpacing.s6,
                children: [
                  Text(
                    'Limite: ${AppFormatters.moeda(resumo.orcamento.valorLimite)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Gasto: ${AppFormatters.moeda(resumo.valorGasto)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    resumo.valorRestante >= 0
                        ? 'Restante: ${AppFormatters.moeda(resumo.valorRestante)}'
                        : 'Excedente: ${AppFormatters.moeda(resumo.valorRestante.abs())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: resumo.valorRestante >= 0
                          ? theme.colorScheme.onSurfaceVariant
                          : statusColor,
                      fontWeight: resumo.valorRestante >= 0
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${(resumo.percentualUtilizado * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
