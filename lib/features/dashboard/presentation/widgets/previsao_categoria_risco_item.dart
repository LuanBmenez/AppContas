import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart'
    show CategoriaGastoInfo;
import 'package:paga_o_que_me_deve/features/dashboard/domain/models/previsao_fechamento_mes.dart';

class PrevisaoCategoriaRiscoItem extends StatelessWidget {
  const PrevisaoCategoriaRiscoItem({
    required this.risco, required this.mostrarValores, super.key,
  });

  final PrevisaoCategoriaRisco risco;
  final bool mostrarValores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentual = risco.percentualPrevistoOrcamento;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: risco.categoria.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: risco.categoria.color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                risco.categoria.icon,
                size: 16,
                color: risco.categoria.color,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  risco.categoria.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${percentual.toStringAsFixed(0)}% do orçamento',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            mostrarValores
                ? 'Previsto ${AppFormatters.moeda(risco.projecaoFimMes)} / orçamento ${AppFormatters.moeda(risco.orcamentoLimite)}'
                : 'Previsto •••• / orçamento ••••',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
