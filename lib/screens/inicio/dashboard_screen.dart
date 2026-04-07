import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/repositories/finance_repository.dart';
import '../../models/conta_model.dart';
import '../../models/dashboard_drilldown_filter.dart';
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
    this.onTapSaidasFiltradas,
  });

  final FinanceRepository db;

  final VoidCallback? onTapSaidas;
  final VoidCallback? onTapReceber;
  final ValueChanged<DashboardDrillDownFilter>? onTapSaidasFiltradas;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardSummaryService _summaryService =
      const DashboardSummaryService();
  final ReportExportService _reportExportService = const ReportExportService();
  DashboardPeriodoRapido _periodo = DashboardPeriodoRapido.mes;
  DateTime? _mesEspecifico;
  bool _exportandoRelatorio = false;
  int _retryTick = 0;

  String _memoKey = '';
  DashboardResumoCalculado? _memoResumo;

  String _tituloPeriodo(DateTime agora) {
    if (_mesEspecifico != null) {
      return 'Mês de ${AppFormatters.nomeMes(_mesEspecifico!.month)}';
    }
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
    final ({DateTime inicio, DateTime fimExclusivo}) faixa = _faixaSelecionada(
      agora,
    );
    return DateTime(faixa.inicio.year, faixa.inicio.month, 1);
  }

  ({DateTime inicio, DateTime fimExclusivo}) _faixaSelecionada(DateTime agora) {
    if (_mesEspecifico != null) {
      final DateTime inicio = DateTime(
        _mesEspecifico!.year,
        _mesEspecifico!.month,
        1,
      );
      final DateTime fimExclusivo = DateTime(
        _mesEspecifico!.year,
        _mesEspecifico!.month + 1,
        1,
      );
      return (inicio: inicio, fimExclusivo: fimExclusivo);
    }
    return _summaryService.faixaAtual(_periodo, agora);
  }

  Future<void> _selecionarMesEspecifico() async {
    final DateTime base = _mesEspecifico ?? DateTime.now();
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Escolha um mês de referência',
    );
    if (data == null) {
      return;
    }
    setState(() {
      _mesEspecifico = DateTime(data.year, data.month, 1);
    });
  }

  void _limparMesEspecifico() {
    setState(() {
      _mesEspecifico = null;
    });
  }

  void _tentarNovamente() {
    setState(() {
      _retryTick++;
    });
  }

  String _insightPrincipal(DashboardResumoCalculado resumo) {
    final DashboardCategoriaResumo? lider = resumo.categoriaMaisGasta;
    if (lider == null) {
      return 'Sem gastos no período. Registre uma saída para gerar insights.';
    }

    final double participacao = resumo.totalGastosPeriodo <= 0
        ? 0
        : (lider.valor / resumo.totalGastosPeriodo) * 100;
    return '${lider.label} concentra ${participacao.toStringAsFixed(1)}% das saídas. Considere revisar esse grupo primeiro.';
  }

  DashboardResumoCalculado _calcularResumoMemoizado(
    DashboardResumo bruto,
    DateTime agora,
  ) {
    final ({DateTime inicio, DateTime fimExclusivo}) faixa = _faixaSelecionada(
      agora,
    );

    final String chave = [
      bruto.gastos.length,
      bruto.contas.length,
      faixa.inicio.millisecondsSinceEpoch,
      faixa.fimExclusivo.millisecondsSinceEpoch,
      _periodo.name,
    ].join('|');

    if (_memoResumo != null && _memoKey == chave) {
      return _memoResumo!;
    }

    final DashboardResumoCalculado resumo = _summaryService.calcularResumo(
      resumo: bruto,
      periodo: _periodo,
      inicioOverride: faixa.inicio,
      fimExclusivoOverride: faixa.fimExclusivo,
      agora: agora,
    );

    _memoKey = chave;
    _memoResumo = resumo;
    return resumo;
  }

  void _abrirDrillDownCategoria(DashboardCategoriaResumo categoria) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final double percentual = (_memoResumo?.totalGastosPeriodo ?? 0) <= 0
            ? 0
            : (categoria.valor / (_memoResumo!.totalGastosPeriodo)) * 100;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(categoria.icon, color: categoria.color),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        categoria.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text('Valor: ${AppFormatters.moeda(categoria.valor)}'),
                Text('Participação: ${percentual.toStringAsFixed(1)}%'),
                const SizedBox(height: AppSpacing.s16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onTapSaidasFiltradas?.call(
                        DashboardDrillDownFilter(
                          mesReferencia: _mesEspecifico ?? DateTime.now(),
                          categoriaPadrao: categoria.categoriaPadrao,
                          categoriaPersonalizadaId:
                              categoria.categoriaPersonalizadaId,
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver gastos desta categoria'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

      try {
        await SharePlus.instance.share(
          ShareParams(
            files: <XFile>[XFile(arquivo.path)],
            subject: 'Relatorio mensal financeiro',
            text:
                'Relatorio ${referencia.month.toString().padLeft(2, '0')}/${referencia.year}',
          ),
        );
      } catch (_) {
        if (mounted) {
          AppFeedback.showSuccess(
            context,
            'PDF gerado em ${arquivo.path}. Compartilhe manualmente se necessário.',
          );
        }
      }

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
      key: ValueKey<int>(_retryTick),
      stream: widget.db.dashboardResumo,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                AppSkeletonBox(height: 28, width: 220),
                SizedBox(height: AppSpacing.s8),
                AppSkeletonBox(height: 18, width: 160),
                SizedBox(height: AppSpacing.s12),
                AppSkeletonBox(height: 34),
                SizedBox(height: AppSpacing.s12),
                AppSkeletonBox(height: 44),
                SizedBox(height: AppSpacing.s24),
                AppSkeletonBox(height: 160, radius: 20),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _mensagemErroDashboard(snapshot.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  const Text(
                    'Verifique conexão, permissões do Firebase e tente novamente.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  FilledButton.icon(
                    onPressed: _tentarNovamente,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }

        final DateTime agora = DateTime.now();
        final DashboardResumo resumoBruto =
            snapshot.data ?? const DashboardResumo(<Gasto>[], <Conta>[]);
        final DashboardResumoCalculado resumo = _calcularResumoMemoizado(
          resumoBruto,
          agora,
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
              const SizedBox(height: AppSpacing.s8),
              Text(
                _insightPrincipal(resumo),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
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
                        _mesEspecifico = null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _selecionarMesEspecifico,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      _mesEspecifico == null
                          ? 'Escolher mês'
                          : AppFormatters.mesAno(_mesEspecifico!),
                    ),
                  ),
                  if (_mesEspecifico != null)
                    InputChip(
                      label: const Text('Mês específico'),
                      onDeleted: _limparMesEspecifico,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
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
                        _exportandoRelatorio
                            ? 'Gerando e compartilhando...'
                            : 'Exportar PDF',
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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      widget.onTapSaidasFiltradas?.call(
                        DashboardDrillDownFilter(
                          mesReferencia: _mesEspecifico ?? DateTime.now(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.s24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: resumo.saldoPositivo
                              ? [Colors.green.shade700, Colors.teal.shade700]
                              : [
                                  Colors.red.shade700,
                                  Colors.deepOrange.shade700,
                                ],
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
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
              ),
              const SizedBox(height: AppSpacing.s12),
              _DashboardEntry(
                delayMs: 70,
                child: Row(
                  children: [
                    Expanded(
                      child: _ComparativoChip(
                        titulo: 'Saldo vs ${resumo.comparativoLabel}',
                        percentual: resumo.variacaoSaldo,
                        positivoEhBom: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _ComparativoChip(
                        titulo: 'Gastos vs ${resumo.comparativoLabel}',
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
                        onTap: () {
                          widget.onTapSaidasFiltradas?.call(
                            DashboardDrillDownFilter(
                              mesReferencia: _mesEspecifico ?? DateTime.now(),
                            ),
                          );
                          if (widget.onTapSaidasFiltradas == null) {
                            widget.onTapSaidas?.call();
                          }
                        },
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
                            onTapCategoria: _abrirDrillDownCategoria,
                          ),
                        const SizedBox(height: AppSpacing.s16),
                        Wrap(
                          spacing: AppSpacing.s12,
                          runSpacing: AppSpacing.s12,
                          children: [
                            _InsightResumoCard(
                              titulo: 'Categoria líder',
                              categoria: resumo.categoriaMaisGasta,
                              valor: resumo.categoriaMaisGasta?.valor ?? 0,
                            ),
                            _InsightResumoCard(
                              titulo: 'Menor participação',
                              categoria: resumo.categoriaMenosGasta,
                              valor: resumo.categoriaMenosGasta?.valor ?? 0,
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
                  color: Colors.grey.shade300,
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
  final DashboardCategoriaResumo? categoria;
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
    this.onTapCategoria,
  });

  final double total;
  final String periodo;
  final List<DashboardCategoriaResumo> data;
  final ValueChanged<DashboardCategoriaResumo>? onTapCategoria;

  @override
  Widget build(BuildContext context) {
    final List<DashboardCategoriaResumo> barras = data.take(6).toList();

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
                categoria: entry,
                total: total,
                onTap: onTapCategoria == null
                    ? null
                    : () => onTapCategoria!(entry),
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
    required this.total,
    this.onTap,
  });

  final DashboardCategoriaResumo categoria;
  final double total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double percentual = total <= 0 ? 0 : categoria.valor / total;
    final String percentualTexto = '${(percentual * 100).toStringAsFixed(1)}%';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoria.icon, size: 14, color: categoria.color),
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
                  AppFormatters.moeda(categoria.valor),
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
        ),
      ),
    );
  }
}
