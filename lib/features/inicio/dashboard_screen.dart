import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/router/app_routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../services/app_telemetry_service.dart';
import '../../services/dashboard_summary_service.dart';
import '../../services/report_export_service.dart';
import '../../ui/ui.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.db,
    this.exportadorRelatorio,
  });

  final FinanceRepository db;
  final Future<void> Function(DateTime referencia)? exportadorRelatorio;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardSummaryService _summaryService = DashboardSummaryService();
  final ReportExportService _reportExportService = const ReportExportService();
  final AppTelemetryService _telemetryService = AppTelemetryService();
  Stream<DashboardResumo>? _dashboardResumoStream;
  DashboardPeriodoRapido _periodo = DashboardPeriodoRapido.mes;
  DateTime? _mesEspecifico;
  bool _exportandoRelatorio = false;

  @override
  void initState() {
    super.initState();
    _dashboardResumoStream = widget.db.dashboardResumo;
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.db != widget.db) {
      _summaryService.clearCache();
      _dashboardResumoStream = widget.db.dashboardResumo;
    }
  }

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

  void _recarregarDashboard() {
    setState(() {
      _summaryService.clearCache();
      _dashboardResumoStream = widget.db.dashboardResumo;
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

  DashboardResumoCalculado _calcularResumo(
    DashboardResumo bruto,
    DateTime agora,
  ) {
    final ({DateTime inicio, DateTime fimExclusivo}) faixa = _faixaSelecionada(
      agora,
    );

    return _summaryService.calcularResumo(
      resumo: bruto,
      periodo: _periodo,
      inicioOverride: faixa.inicio,
      fimExclusivoOverride: faixa.fimExclusivo,
      agora: agora,
    );
  }

  void _irParaDespesas({DashboardDrillDownFilter? filter}) {
    final Map<String, dynamic> query = filter == null
        ? <String, dynamic>{}
        : <String, dynamic>{...AppRoutes.despesasQueryFromFilter(filter)};
    context.goNamed(AppRoutes.despesasName, queryParameters: query);
  }

  void _abrirDrillDownCategoria(
    DashboardCategoriaResumo categoria,
    double totalGastosPeriodo,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final double percentual = totalGastosPeriodo <= 0
            ? 0
            : (categoria.valor / totalGastosPeriodo) * 100;
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
                      _irParaDespesas(
                        filter: DashboardDrillDownFilter(
                          mesReferencia: _mesEspecifico,
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

  Future<void> _exportarRelatorioMensal({required String origemAcao}) async {
    if (_exportandoRelatorio) {
      _telemetryService.logEvent(
        AppTelemetryEvents.dashboardExportPdfIgnoredBusy,
        params: <String, Object?>{'origemAcao': origemAcao},
      );
      return;
    }

    final Stopwatch cronometro = Stopwatch()..start();
    final DateTime referencia = _mesReferenciaExportacao(DateTime.now());
    bool sucesso = false;
    bool fallbackCompartilhamento = false;
    String? erroTipo;
    String? mensagemFeedback;

    _telemetryService.logEvent(
      AppTelemetryEvents.dashboardExportPdfStarted,
      params: <String, Object?>{
        'origemAcao': origemAcao,
        'referenciaAno': referencia.year,
        'referenciaMes': referencia.month,
      },
    );

    if (kIsWeb) {
      _telemetryService.logEvent(
        AppTelemetryEvents.dashboardExportPdfUnsupportedPlatform,
        params: <String, Object?>{
          'origemAcao': origemAcao,
          'platform': 'web',
          'duracaoMs': cronometro.elapsedMilliseconds,
        },
      );
      AppFeedback.showError(
        context,
        'Exportacao de arquivo indisponivel no navegador nesta versao.',
      );
      return;
    }

    setState(() => _exportandoRelatorio = true);
    try {
      if (widget.exportadorRelatorio != null) {
        await widget.exportadorRelatorio!(referencia);
        sucesso = true;
        mensagemFeedback = 'Relatorio PDF gerado com sucesso.';
        return;
      }

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
        sucesso = true;
        mensagemFeedback = 'Relatorio PDF gerado com sucesso.';
      } catch (_) {
        sucesso = true;
        fallbackCompartilhamento = true;
        mensagemFeedback =
            'PDF gerado em ${arquivo.path}. Compartilhe manualmente se necessário.';
      }
    } catch (e) {
      erroTipo = e.runtimeType.toString();
      _telemetryService.logEvent(
        AppTelemetryEvents.dashboardExportPdfException,
        params: <String, Object?>{
          'origemAcao': origemAcao,
          'erroTipo': erroTipo,
          'erroMensagem': e.toString(),
        },
      );
      if (mounted) {
        AppFeedback.showError(
          context,
          'Falha ao exportar relatorio. Tente novamente.',
        );
      }
    } finally {
      cronometro.stop();
      _telemetryService.logEvent(
        AppTelemetryEvents.dashboardExportPdfFinished,
        params: <String, Object?>{
          'origemAcao': origemAcao,
          'referenciaAno': referencia.year,
          'referenciaMes': referencia.month,
          'duracaoMs': cronometro.elapsedMilliseconds,
          'sucesso': sucesso,
          'fallbackCompartilhamento': fallbackCompartilhamento,
          'erroTipo': erroTipo,
        },
      );

      if (mounted && sucesso && mensagemFeedback != null) {
        AppFeedback.showSuccess(context, mensagemFeedback);
      }

      if (mounted) {
        setState(() => _exportandoRelatorio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardResumo>(
      stream: _dashboardResumoStream,
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
                    onPressed: _recarregarDashboard,
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
        final DashboardResumoCalculado resumo = _calcularResumo(
          resumoBruto,
          agora,
        );

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool telaCompacta = constraints.maxHeight < 700;
              return ListView(
                children: [
                  _DashboardHeaderPeriodoSection(
                    periodoTitulo: _tituloPeriodo(agora),
                    insight: _insightPrincipal(resumo),
                    acaoPrincipalLabel: 'Ver gastos do mês',
                    periodoSelecionado: _periodo,
                    labelPeriodo: _labelPeriodo,
                    onSelecionarPeriodo: (periodo) {
                      setState(() {
                        _periodo = periodo;
                        _mesEspecifico = null;
                      });
                    },
                    mesEspecifico: _mesEspecifico,
                    onSelecionarMes: _selecionarMesEspecifico,
                    onLimparMes: _limparMesEspecifico,
                    exportandoRelatorio: _exportandoRelatorio,
                    onAcaoPrincipal: () {
                      _irParaDespesas(
                        filter: DashboardDrillDownFilter(
                          mesReferencia: _mesEspecifico ?? DateTime.now(),
                        ),
                      );
                    },
                    onExportarPdf: () => _exportarRelatorioMensal(
                      origemAcao: 'dashboard_top_secondary',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  _DashboardEntry(
                    delayMs: 0,
                    child: _DashboardSaldoSection(
                      saldo: resumo.saldo,
                      saldoPositivo: resumo.saldoPositivo,
                      onTap: () {
                        _irParaDespesas(
                          filter: DashboardDrillDownFilter(
                            mesReferencia: _mesEspecifico,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  _DashboardEntry(
                    delayMs: 70,
                    child: _DashboardComparativosSection(
                      comparativoLabel: resumo.comparativoLabel,
                      variacaoSaldo: resumo.variacaoSaldo,
                      variacaoGastos: resumo.variacaoGastos,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  _DashboardEntry(
                    delayMs: 130,
                    child: _DashboardResumoCardsSection(
                      totalGastosPeriodo: resumo.totalGastosPeriodo,
                      totalPendente: resumo.totalPendente,
                      onTapSaidas: () {
                        _irParaDespesas(
                          filter: DashboardDrillDownFilter(
                            mesReferencia: _mesEspecifico,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  _DashboardEntry(
                    delayMs: 180,
                    child: _DashboardCategoriasSection(
                      tituloPeriodo: _tituloPeriodo(agora),
                      resumo: resumo,
                      onTapCategoria: (categoria) => _abrirDrillDownCategoria(
                        categoria,
                        resumo.totalGastosPeriodo,
                      ),
                    ),
                  ),
                  if (!telaCompacta) ...[
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
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _DashboardHeaderPeriodoSection extends StatelessWidget {
  const _DashboardHeaderPeriodoSection({
    required this.periodoTitulo,
    required this.insight,
    required this.acaoPrincipalLabel,
    required this.periodoSelecionado,
    required this.labelPeriodo,
    required this.onSelecionarPeriodo,
    required this.mesEspecifico,
    required this.onSelecionarMes,
    required this.onLimparMes,
    required this.exportandoRelatorio,
    required this.onAcaoPrincipal,
    required this.onExportarPdf,
  });

  final String periodoTitulo;
  final String insight;
  final String acaoPrincipalLabel;
  final DashboardPeriodoRapido periodoSelecionado;
  final String Function(DashboardPeriodoRapido) labelPeriodo;
  final ValueChanged<DashboardPeriodoRapido> onSelecionarPeriodo;
  final DateTime? mesEspecifico;
  final VoidCallback onSelecionarMes;
  final VoidCallback onLimparMes;
  final bool exportandoRelatorio;
  final VoidCallback onAcaoPrincipal;
  final VoidCallback onExportarPdf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumo Financeiro',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          periodoTitulo,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          insight,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
        ),
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: DashboardPeriodoRapido.values.map((periodo) {
            final bool selecionado = periodoSelecionado == periodo;
            return ChoiceChip(
              label: Text(labelPeriodo(periodo)),
              selected: selecionado,
              onSelected: (_) => onSelecionarPeriodo(periodo),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            OutlinedButton.icon(
              onPressed: onSelecionarMes,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                mesEspecifico == null
                    ? 'Escolher mês'
                    : AppFormatters.mesAno(mesEspecifico!),
              ),
            ),
            if (mesEspecifico != null)
              InputChip(
                label: const Text('Mês específico'),
                onDeleted: onLimparMes,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAcaoPrincipal,
                icon: const Icon(Icons.open_in_new),
                label: Text(acaoPrincipalLabel),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: exportandoRelatorio ? null : onExportarPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  exportandoRelatorio
                      ? 'Gerando e compartilhando...'
                      : 'Exportar PDF',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardSaldoSection extends StatelessWidget {
  const _DashboardSaldoSection({
    required this.saldo,
    required this.saldoPositivo,
    this.onTap,
  });

  final double saldo;
  final bool saldoPositivo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: saldoPositivo
                  ? [Colors.green.shade700, Colors.teal.shade700]
                  : [Colors.red.shade700, Colors.deepOrange.shade700],
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
                AppFormatters.moeda(saldo),
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
    );
  }
}

class _DashboardComparativosSection extends StatelessWidget {
  const _DashboardComparativosSection({
    required this.comparativoLabel,
    required this.variacaoSaldo,
    required this.variacaoGastos,
  });

  final String comparativoLabel;
  final double variacaoSaldo;
  final double variacaoGastos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ComparativoChip(
            titulo: 'Saldo vs $comparativoLabel',
            percentual: variacaoSaldo,
            positivoEhBom: true,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: _ComparativoChip(
            titulo: 'Gastos vs $comparativoLabel',
            percentual: variacaoGastos,
            positivoEhBom: false,
          ),
        ),
      ],
    );
  }
}

class _DashboardResumoCardsSection extends StatelessWidget {
  const _DashboardResumoCardsSection({
    required this.totalGastosPeriodo,
    required this.totalPendente,
    this.onTapSaidas,
  });

  final double totalGastosPeriodo;
  final double totalPendente;
  final VoidCallback? onTapSaidas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniSummaryCard(
            titulo: 'Saídas',
            valor: totalGastosPeriodo,
            cor: Colors.red,
            icone: Icons.arrow_downward,
            onTap: onTapSaidas,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: _MiniSummaryCard(
            titulo: 'Pendências',
            valor: totalPendente,
            cor: Colors.orange,
            icone: Icons.pending_actions,
          ),
        ),
      ],
    );
  }
}

class _DashboardCategoriasSection extends StatelessWidget {
  const _DashboardCategoriasSection({
    required this.tituloPeriodo,
    required this.resumo,
    this.onTapCategoria,
  });

  final String tituloPeriodo;
  final DashboardResumoCalculado resumo;
  final ValueChanged<DashboardCategoriaResumo>? onTapCategoria;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categorias de gastos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Distribuição dos gastos no mês',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Total analisado: ${AppFormatters.moeda(resumo.totalGastosPeriodo)} • ${resumo.categoriasOrdenadas.length} categorias ativas',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.7),
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
                periodo: tituloPeriodo,
                data: resumo.categoriasOrdenadas,
                onTapCategoria: onTapCategoria,
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
                  valor: resumo.categoriasOrdenadas.length.toDouble(),
                  labelUnico: true,
                ),
              ],
            ),
          ],
        ),
      ),
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
