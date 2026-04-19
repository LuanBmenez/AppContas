import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';

class DashboardGuardadoCard extends StatelessWidget {
  const DashboardGuardadoCard({
    required this.resumo,
    required this.jaGuardadoMes,
    required this.referenciaMes,
    required this.mostrarValores,
    super.key,
  });

  final DashboardResumoCalculado resumo;
  final double jaGuardadoMes;
  final DateTime referenciaMes;
  final bool mostrarValores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final temSobra = resumo.saldo > 0;
    final valorGuardavel = temSobra ? resumo.saldo : 0.00;
    final nomeMes = AppFormatters.nomeMes(referenciaMes.month);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go(AppRoutes.guardadoPath),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D7A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  color: Color(0xFF0F9D7A),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sobra para guardar',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      mostrarValores
                          ? AppFormatters.moeda(valorGuardavel)
                          : '••••',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      mostrarValores
                          ? 'Já guardado em $nomeMes: ${AppFormatters.moeda(jaGuardadoMes)}'
                          : 'Já guardado em $nomeMes: ••••',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      temSobra
                          ? 'Toque para escolher o destino, editar movimentações e acompanhar metas.'
                          : 'Abra Guardado para ver metas, resgates e valores já separados.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
