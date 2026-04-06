import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/repositories/finance_repository.dart';
import '../../models/conta_model.dart';
import '../../models/gasto_model.dart';
import '../../services/dashboard_summary_service.dart';
import '../../services/report_export_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_feedback.dart';
import '../../utils/app_formatters.dart';
import '../../widgets/app_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.db,
    this.onTapSaidas,
    this.onTapReceber,
  });

  final FinanceRepository db;

  final VoidCallback? onTapSaidas;
  final VoidCallback? onTapReceber;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardSummaryService _summaryService =
      const DashboardSummaryService();
  final ReportExportService _reportExportService = const ReportExportService();
  DashboardPeriodoRapido _periodo = DashboardPeriodoRapido.mes;
  bool _exportandoRelatorio = false;

  String _tituloPeriodo(DateTime agora) {
    switch (_periodo) {
      case DashboardPeriodoRapido.hoje:
        return 'Hoje';
      case DashboardPeriodoRapido.seteDias:
        return 'Últimos 7 dias';
      case DashboardPeriodoRapido.mes:
        return 'Mês de ${AppFormatters.nomeMes(agora.month)}';
      case DashboardPeriodoRapido.trimestre:
        return 'Últimos 3 meses';
    }
  }

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

  String _mensagemErroDashboard(Object? error) {
    final String erro = (error ?? '').toString().toLowerCase();
    if (erro.contains('firestore.googleapis.com') ||
        erro.contains('permission_denied')) {
      return 'Firestore sem permissao ou desativado no projeto.\n'
          'Ative o Cloud Firestore no Firebase Console e tente novamente.';
    }
    return 'Erro ao carregar o painel.';
  }

  DateTime _mesReferenciaExportacao(DateTime agora) {
    final ({DateTime inicio, DateTime fimExclusivo}) faixa = _summaryService
        .faixaAtual(_periodo, agora);
    return DateTime(faixa.inicio.year, faixa.inicio.month, 1);
  }

  Future<void> _exportarRelatorioMensal() async {
    if (_exportandoRelatorio) {
      return;
    }

    if (kIsWeb) {
      AppFeedback.showError(
        context,
        'Exportacao de arquivo indisponivel no navegador nesta versao.',
      );
      return;
    }

    setState(() => _exportandoRelatorio = true);
    try {
      final DateTime referencia = _mesReferenciaExportacao(DateTime.now());
      final RelatorioMensalFinanceiro relatorio = await widget.db
          .buscarRelatorioMensal(referencia);
      final RelatorioExportado exportado = await _reportExportService
          .gerarRelatorioMensal(relatorio);

      final Directory tempDir = await getTemporaryDirectory();
      final File arquivo = File(
        '${tempDir.path}/${exportado.nomeArquivoBase}.pdf',
      );

      await arquivo.writeAsBytes(exportado.pdfBytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(arquivo.path)],
          subject: 'Relatorio mensal financeiro',
          text:
              'Relatorio ${referencia.month.toString().padLeft(2, '0')}/${referencia.year}',
        ),
      );

      if (mounted) {
        AppFeedback.showSuccess(context, 'Relatorio PDF gerado com sucesso.');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Falha ao exportar relatorio: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _exportandoRelatorio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardResumo>(
      stream: widget.db.dashboardResumo,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DashboardSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Text(
                _mensagemErroDashboard(snapshot.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final DateTime agora = DateTime.now();
        final DashboardResumo resumoBruto =
            snapshot.data ?? const DashboardResumo(<Gasto>[], <Conta>[]);
        final DashboardResumoCalculado resumo = _summaryService.calcularResumo(
          resumo: resumoBruto,
          periodo: _periodo,
          agora: agora,
        );

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: ListView(
            children: [
              const Text(
                'Resumo Financeiro',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                _tituloPeriodo(agora),
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: DashboardPeriodoRapido.values.map((periodo) {
                  final bool selecionado = _periodo == periodo;
                  return ChoiceChip(
                    label: Text(_labelPeriodo(periodo)),
                    selected: selecionado,
                    onSelected: (_) {
                      setState(() {
                        _periodo = periodo;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportandoRelatorio
                          ? null
                          : _exportarRelatorioMensal,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _exportandoRelatorio ? 'Gerando...' : 'Exportar PDF',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),
              _DashboardEntry(
                delayMs: 0,
                child: Card(
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: resumo.saldoPositivo
                            ? [Colors.green.shade400, Colors.teal.shade500]
                            : [Colors.red.shade400, Colors.deepOrange.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Saldo Mensal (Recebido - Gastos)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          AppFormatters.moeda(resumo.saldo),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              _DashboardEntry(
                delayMs: 70,
                child: Row(
                  children: [
                    Expanded(
                      child: _ComparativoChip(
                        titulo: 'Saldo vs mês anterior',
                        percentual: resumo.variacaoSaldo,
                        positivoEhBom: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _ComparativoChip(
                        titulo: 'Gastos vs mês anterior',
                        percentual: resumo.variacaoGastos,
                        positivoEhBom: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              _DashboardEntry(
                delayMs: 130,
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniSummaryCard(
                        titulo: 'Saídas',
                        valor: resumo.totalGastosPeriodo,
                        cor: Colors.red,
                        icone: Icons.arrow_downward,
                        onTap: widget.onTapSaidas,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _MiniSummaryCard(
                        titulo: 'A Receber',
                        valor: resumo.totalPendente,
                        cor: Colors.orange,
                        icone: Icons.pending_actions,
                        onTap: widget.onTapReceber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              _DashboardEntry(
                delayMs: 180,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categorias de gastos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Distribuição dos gastos no mês',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          'Total analisado: ${AppFormatters.moeda(resumo.totalGastosPeriodo)} • ${resumo.categoriasOrdenadas.length} categorias ativas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        if (resumo.categoriasOrdenadas.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                              vertical: AppSpacing.s24,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.pie_chart_outline,
                                  size: 42,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.35),
                                ),
                                const SizedBox(height: AppSpacing.s12),
                                const Text(
                                  'Sem gastos no período para montar o gráfico.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                Text(
                                  'Adicione gastos para ver a distribuição por categoria.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          _CategoriasBarrasCard(
                            total: resumo.totalGastosPeriodo,
                            periodo: _tituloPeriodo(agora),
                            data: resumo.categoriasOrdenadas,
                          ),
                        const SizedBox(height: AppSpacing.s16),
                        Wrap(
                          spacing: AppSpacing.s12,
                          runSpacing: AppSpacing.s12,
                          children: [
                            _InsightResumoCard(
                              titulo: 'Categoria líder',
                              categoria: resumo.categoriaMaisGasta?.key,
                              valor: resumo.categoriaMaisGasta?.value ?? 0,
                            ),
                            _InsightResumoCard(
                              titulo: 'Menor participação',
                              categoria: resumo.categoriaMenosGasta?.key,
                              valor: resumo.categoriaMenosGasta?.value ?? 0,
                            ),
                            _InsightResumoCard(
                              titulo: 'Categorias ativas',
                              valor: resumo.categoriasOrdenadas.length
                                  .toDouble(),
                              labelUnico: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              Center(
                child: Icon(
                  Icons.insights,
                  size: 100,
                  color: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        );
      },
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
    this.onTap,
  });

  final String titulo;
  final double valor;
  final Color cor;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icone, size: 16, color: cor),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 13,
                      color: cor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                AppFormatters.moeda(valor),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparativoChip extends StatelessWidget {
  const _ComparativoChip({
    required this.titulo,
    required this.percentual,
    required this.positivoEhBom,
  });

  final String titulo;
  final double percentual;
  final bool positivoEhBom;

  @override
  Widget build(BuildContext context) {
    final bool subiu = percentual >= 0;
    final bool bom = positivoEhBom ? subiu : !subiu;
    final Color cor = bom ? Colors.green : Colors.red;
    final IconData icone = subiu ? Icons.trending_up : Icons.trending_down;

    return Card(
      elevation: 0,
      color: cor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        child: Row(
          children: [
            Icon(icone, color: cor, size: 16),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                '$titulo: ${percentual.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: cor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardEntry extends StatelessWidget {
  const _DashboardEntry({required this.child, required this.delayMs});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: AppMotion.fast.inMilliseconds + delayMs),
      curve: AppMotion.curve,
      builder: (context, value, _) {
        final double slide = (1 - value) * 0.04;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * slide),
            child: child,
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class _InsightResumoCard extends StatelessWidget {
  const _InsightResumoCard({
    required this.titulo,
    this.categoria,
    required this.valor,
    this.labelUnico = false,
  });

  final String titulo;
  final CategoriaGasto? categoria;
  final double valor;
  final bool labelUnico;

  @override
  Widget build(BuildContext context) {
    final Color cor = categoria?.color ?? Theme.of(context).colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: cor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (labelUnico)
            Text(
              valor.toInt().toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            )
          else ...[
            Text(
              categoria?.label ?? 'Sem dados',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              AppFormatters.moeda(valor),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoriasBarrasCard extends StatelessWidget {
  const _CategoriasBarrasCard({
    required this.total,
    required this.periodo,
    required this.data,
  });

  final double total;
  final String periodo;
  final List<MapEntry<CategoriaGasto, double>> data;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<CategoriaGasto, double>> barras = data.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      AppFormatters.moeda(total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${data.length} categorias',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          ...barras.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: _BarraCategoriaLinha(
                categoria: entry.key,
                valor: entry.value,
                total: total,
              ),
            ),
          ),
          if (data.length > barras.length)
            Text(
              '+ ${data.length - barras.length} categorias adicionais',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _BarraCategoriaLinha extends StatelessWidget {
  const _BarraCategoriaLinha({
    required this.categoria,
    required this.valor,
    required this.total,
  });

  final CategoriaGasto categoria;
  final double valor;
  final double total;

  @override
  Widget build(BuildContext context) {
    final double percentual = total <= 0 ? 0 : valor / total;
    final String percentualTexto = '${(percentual * 100).toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: categoria.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                categoria.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              percentualTexto,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              AppFormatters.moeda(valor),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: percentual,
            backgroundColor: categoria.color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(categoria.color),
          ),
        ),
      ],
    );
  }
}
