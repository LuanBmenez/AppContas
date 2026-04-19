import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/categorias_barras_card.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/insight_resumo_card.dart';

class DashboardCategoriasSection extends StatelessWidget {
  const DashboardCategoriasSection({
    required this.resumo, required this.periodoTitulo, required this.mostrarValores, super.key,
    this.onTapCategoria,
    this.onTapSaidas,
  });

  final DashboardResumoCalculado resumo;
  final String periodoTitulo;
  final bool mostrarValores;
  final ValueChanged<DashboardCategoriaResumo>? onTapCategoria;
  final VoidCallback? onTapSaidas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            Text(
              'Categorias de gastos',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Distribuição do período selecionado',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mostrarValores
                  ? 'Total analisado: ${AppFormatters.moeda(resumo.totalGastosPeriodo)} • ${resumo.categoriasOrdenadas.length} categorias ativas'
                  : 'Total analisado: •••• • ${resumo.categoriasOrdenadas.length} categorias ativas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (resumo.categoriasOrdenadas.isEmpty)
              _CategoriasVazias(onTapSaidas: onTapSaidas)
            else
              CategoriasBarrasCard(
                total: resumo.totalGastosPeriodo,
                periodo: periodoTitulo,
                data: resumo.categoriasOrdenadas,
                mostrarValores: mostrarValores,
                onTapCategoria: onTapCategoria,
              ),
            const SizedBox(height: AppSpacing.s16),
            LayoutBuilder(
              builder: (context, constraints) {
                final Widget cardLider = InsightResumoCard(
                  titulo: 'Categoria líder',
                  categoria: resumo.categoriaMaisGasta,
                  valor: resumo.categoriaMaisGasta?.valor ?? 0,
                  mostrarValores: mostrarValores,
                );

                final Widget cardMenor = InsightResumoCard(
                  titulo: 'Menor participação',
                  categoria: resumo.categoriaMenosGasta,
                  valor: resumo.categoriaMenosGasta?.valor ?? 0,
                  mostrarValores: mostrarValores,
                );

                final Widget cardAtivas = InsightResumoCard(
                  titulo: 'Categorias ativas',
                  valor: resumo.categoriasOrdenadas.length.toDouble(),
                  labelUnico: true,
                  mostrarValores: mostrarValores,
                );

                if (constraints.maxWidth < 820) {
                  return Column(
                    children: [
                      cardLider,
                      const SizedBox(height: AppSpacing.s12),
                      cardMenor,
                      const SizedBox(height: AppSpacing.s12),
                      cardAtivas,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cardLider),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: cardMenor),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: cardAtivas),
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

class _CategoriasVazias extends StatelessWidget {
  const _CategoriasVazias({this.onTapSaidas});

  final VoidCallback? onTapSaidas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 42,
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: AppSpacing.s12),
          const Text(
            'Sem gastos no período para montar o gráfico.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Adicione gastos para ver a distribuição por categoria.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Wrap(
            spacing: AppSpacing.s10,
            runSpacing: AppSpacing.s10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () {
                  if (onTapSaidas != null) {
                    onTapSaidas!.call();
                    return;
                  }
                  context.push(AppRoutes.novoGastoPath);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar gasto'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.importarPath),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Importar CSV'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
