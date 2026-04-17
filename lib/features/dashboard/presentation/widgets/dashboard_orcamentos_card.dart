import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/orcamentos.dart';

class DashboardOrcamentosCard extends StatelessWidget {
  const DashboardOrcamentosCard({
    super.key,
    required this.orcamentosMesStream,
  });

  final Stream<List<OrcamentoCategoriaResumo>> orcamentosMesStream;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Orçamentos do mês',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.orcamentosPath),
                  child: const Text('Gerenciar'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
            Text(
              'Acompanhe limites por categoria no mês atual.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            StreamBuilder<List<OrcamentoCategoriaResumo>>(
              stream: orcamentosMesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Column(
                    children: [
                      AppSkeletonBox(height: 84, radius: 14),
                      SizedBox(height: AppSpacing.s10),
                      AppSkeletonBox(height: 84, radius: 14),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Não foi possível carregar orçamentos: ${snapshot.error}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  );
                }

                final List<OrcamentoCategoriaResumo> resumos =
                    snapshot.data ?? <OrcamentoCategoriaResumo>[];

                if (resumos.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Você ainda não definiu orçamentos por categoria.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.orcamentosPath),
                          icon: const Icon(Icons.add),
                          label: const Text('Criar orçamento'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < resumos.length; i++) ...[
                      OrcamentoCategoriaProgressItem(
                        resumo: resumos[i],
                        compacto: true,
                        onTap: () => context.push(AppRoutes.orcamentosPath),
                      ),
                      if (i != resumos.length - 1)
                        const SizedBox(height: AppSpacing.s10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
