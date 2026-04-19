import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';

class DashboardHeroSaldoCard extends StatelessWidget {
  const DashboardHeroSaldoCard({
    required this.resumo, required this.mostrarValores, super.key,
    this.onTap,
  });

  final DashboardResumoCalculado resumo;
  final bool mostrarValores;
  final VoidCallback? onTap;

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
    final saldoPositivo = resumo.saldoPositivo;
    final colors = saldoPositivo
        ? [semantic.success, semantic.success.withValues(alpha: 0.85)]
        : [semantic.error, semantic.error.withValues(alpha: 0.85)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    saldoPositivo ? 'Saldo positivo' : 'Atenção',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Saldo do período',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mostrarValores ? AppFormatters.moeda(resumo.saldo) : '••••',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Recebido - gastos no período selecionado',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
