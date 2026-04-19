import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';

class DashboardPeriodFilters extends StatelessWidget {
  const DashboardPeriodFilters({
    required this.periodoSelecionado, required this.mesEspecifico, required this.onPeriodoChanged, required this.onSelecionarMes, required this.onLimparMes, super.key,
  });

  final DashboardPeriodoRapido periodoSelecionado;
  final DateTime? mesEspecifico;
  final ValueChanged<DashboardPeriodoRapido> onPeriodoChanged;
  final VoidCallback onSelecionarMes;
  final VoidCallback onLimparMes;

  String _labelPeriodo(DashboardPeriodoRapido periodo) {
    switch (periodo) {
      case DashboardPeriodoRapido.hoje:
        return 'Hoje';
      case DashboardPeriodoRapido.seteDias:
        return '7 dias';
      case DashboardPeriodoRapido.mes:
        return 'Mês';
      case DashboardPeriodoRapido.trimestre:
        return 'Trimestre';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DashboardPeriodoRapido.values.map((periodo) {
            final selecionado =
                periodoSelecionado == periodo && mesEspecifico == null;

            return ChoiceChip(
              label: Text(_labelPeriodo(periodo)),
              selected: selecionado,
              showCheckmark: false,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selecionado
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: selecionado
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              onSelected: (_) => onPeriodoChanged(periodo),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionPill(
              icon: Icons.calendar_month_outlined,
              label: mesEspecifico == null
                  ? 'Escolher mês'
                  : AppFormatters.mesAno(mesEspecifico!),
              onTap: onSelecionarMes,
            ),
            if (mesEspecifico != null)
              InputChip(
                label: const Text('Mês específico'),
                onDeleted: onLimparMes,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
