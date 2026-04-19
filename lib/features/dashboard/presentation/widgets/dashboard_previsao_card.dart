import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/previsao_fechamento_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/domain/models/previsao_fechamento_mes.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/previsao_categoria_risco_item.dart';
import 'package:paga_o_que_me_deve/features/insights/insights.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/orcamentos.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/data/services/recorrencias_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';

class DashboardPrevisaoCard extends StatelessWidget {
  const DashboardPrevisaoCard({
    super.key,
    required this.resumoBruto,
    required this.resumo,
    required this.agora,
    required this.mostrarValores,
    required this.orcamentosMesStream,
    required this.recorrenciasService,
    required this.previsaoFechamentoService,
    required this.insightsService,
    required this.referenciaMesRecorrencias,
    required this.calcularRecorrenciasRestantesMes,
  });

  final DashboardResumo resumoBruto;
  final DashboardResumoCalculado resumo;
  final DateTime agora;
  final bool mostrarValores;
  final Stream<List<OrcamentoCategoriaResumo>> orcamentosMesStream;
  final RecorrenciasService recorrenciasService;
  final PrevisaoFechamentoService previsaoFechamentoService;
  final InsightsService insightsService;
  final DateTime referenciaMesRecorrencias;
  final double Function(List<RecorrenciaAtiva>, DateTime)
  calcularRecorrenciasRestantesMes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return StreamBuilder<List<OrcamentoCategoriaResumo>>(
      stream: orcamentosMesStream,
      builder: (context, snapshotOrcamentos) {
        final List<OrcamentoCategoriaResumo> orcamentos =
            snapshotOrcamentos.data ?? <OrcamentoCategoriaResumo>[];

        final PrevisaoFechamentoMes previsao = previsaoFechamentoService
            .calcular(
              resumo: resumoBruto,
              orcamentosCategoria: orcamentos,
              agora: agora,
            );

        final List<PrevisaoCategoriaRisco> riscos = previsao.categoriasComRisco
            .take(3)
            .toList();

        return StreamBuilder<List<RecorrenciaAtiva>>(
          stream: recorrenciasService.streamRecorrenciasAtivas(),
          builder: (context, snapshotRecorrencias) {
            final List<RecorrenciaAtiva> recorrencias =
                snapshotRecorrencias.data ?? <RecorrenciaAtiva>[];

            final double recorrenciasRestantesCorrigidas =
                calcularRecorrenciasRestantesMes(
                  recorrencias,
                  referenciaMesRecorrencias,
                );

            // final double projecaoTotalCorrigida =
            //     previsao.projecaoTotal -
            //     previsao.recorrenciasRestantes +
            //     recorrenciasRestantesCorrigidas;

            final List<InsightItem> insights = insightsService.gerarInsights(
              resumo: resumo,
              previsao: previsao,
              orcamentos: orcamentos,
              agora: agora,
              limite: 5,
            );

            return Column(
              children: [
                Card(
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
                          'Previsão do mês',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s6),
                        Text(
                          'Com base no ritmo diário e recorrências previstas.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          // decoration: BoxDecoration(
                          //   gradient: LinearGradient(
                          //     colors: [
                          //       theme.colorScheme.primary.withValues(
                          //         alpha: 0.13,
                          //       ),
                          //       theme.colorScheme.primary.withValues(
                          //         alpha: 0.06,
                          //       ),
                          //     ],
                          //     begin: Alignment.topLeft,
                          //     end: Alignment.bottomRight,
                          //   ),
                          //   borderRadius: BorderRadius.circular(20),
                          //   border: Border.all(
                          //     color: theme.colorScheme.primary.withValues(
                          //       alpha: 0.12,
                          //     ),
                          //   ),
                          // ),
                          // child: Column(
                          //   crossAxisAlignment: CrossAxisAlignment.start,
                          //   children: [
                          //     Text(
                          //       'Fechamento previsto',
                          //       style: theme.textTheme.labelLarge?.copyWith(
                          //         color: theme.colorScheme.primary,
                          //         fontWeight: FontWeight.w700,
                          //       ),
                          //     ),
                          //     const SizedBox(height: AppSpacing.s8),
                          //     Text(
                          //       mostrarValores
                          //           ? AppFormatters.moeda(projecaoTotalCorrigida)
                          //           : '••••',
                          //       style: theme.textTheme.headlineSmall?.copyWith(
                          //         fontWeight: FontWeight.w800,
                          //         letterSpacing: -0.4,
                          //       ),
                          //     ),
                          //     const SizedBox(height: AppSpacing.s6),
                          //     Text(
                          //       mostrarValores
                          //           ? 'Mantendo o ritmo atual, você deve fechar o mês em ${AppFormatters.moeda(projecaoTotalCorrigida)}.'
                          //           : 'Mantendo o ritmo atual, você deve fechar o mês em ••••.',
                          //       style: theme.textTheme.bodySmall?.copyWith(
                          //         color: theme.colorScheme.onSurfaceVariant,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.s14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recorrências restantes',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s6),
                              Text(
                                mostrarValores
                                    ? AppFormatters.moeda(
                                        recorrenciasRestantesCorrigidas,
                                      )
                                    : '••••',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                recorrenciasRestantesCorrigidas > 0
                                    ? (mostrarValores
                                          ? 'Ainda faltam ${AppFormatters.moeda(recorrenciasRestantesCorrigidas)} em despesas recorrentes previstas.'
                                          : 'Ainda faltam •••• em despesas recorrentes previstas.')
                                    : 'Sem despesas recorrentes pendentes para este mês.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Text(
                          'Categorias em risco',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s10),
                        if (riscos.isEmpty)
                          Text(
                            'Sem risco de estouro nas categorias com orçamento.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Column(
                            children: riscos.map((
                              PrevisaoCategoriaRisco risco,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s10,
                                ),
                                child: PrevisaoCategoriaRiscoItem(
                                  risco: risco,
                                  mostrarValores: mostrarValores,
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s14),
                InsightsListCard(insights: insights),
              ],
            );
          },
        );
      },
    );
  }
}
