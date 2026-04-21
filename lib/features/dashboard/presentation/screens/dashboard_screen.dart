import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/di/service_locator.dart';
import 'package:paga_o_que_me_deve/core/errors/app_exceptions.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/dashboard_data_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/previsao_fechamento_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/report_export_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/controllers/dashboard_screen_controller.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/comparativo_chip.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_categorias_section.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_drilldown_sheet.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_entry.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_export_card.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_guardado_card.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_header_section.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_hero_saldo_card.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_loading_view.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_orcamentos_card.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_period_filters.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_previsao_card.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/mini_summary_card.dart';
import 'package:paga_o_que_me_deve/features/insights/insights.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/orcamentos.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/data/services/recorrencias_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.exportadorRelatorio,
    this.orcamentosMesStreamOverride,
    this.onTapSaidas,
    this.onTapReceber,
    this.onTapSaidasFiltradas,
  });

  final Future<void> Function(DateTime referencia)? exportadorRelatorio;
  final Stream<List<OrcamentoCategoriaResumo>>? orcamentosMesStreamOverride;
  final VoidCallback? onTapSaidas;
  final VoidCallback? onTapReceber;
  final ValueChanged<DashboardDrillDownFilter>? onTapSaidasFiltradas;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final FinanceRepository _db;
  late final DashboardDataService _dashboardDataService;
  late final Stream<List<OrcamentoCategoriaResumo>> _orcamentosMesStream;
  late final RecorrenciasService _recorrenciasService;
  late final DashboardScreenController _controller;

  final DashboardSummaryService _summaryService = DashboardSummaryService();
  final PrevisaoFechamentoService _previsaoFechamentoService =
      const PrevisaoFechamentoService();
  final InsightsService _insightsService = const InsightsService();
  final ReportExportService _reportExportService = const ReportExportService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _exportandoRelatorio = false;

  @override
  void initState() {
    super.initState();
    _db = getIt<FinanceRepository>();
    _controller = DashboardScreenController(summaryService: _summaryService);
    _dashboardDataService = DashboardDataService(_db);
    _recorrenciasService = RecorrenciasService(repository: _db);

    final streamOverride = widget.orcamentosMesStreamOverride;

    if (streamOverride != null) {
      _orcamentosMesStream = streamOverride.isBroadcast
          ? streamOverride
          : streamOverride.asBroadcastStream();
      return;
    }

    try {
      final orcamentosService = OrcamentosService(repository: _db);
      final stream = orcamentosService.calcularResumoPorCategoria(
        DateTime.now(),
        limite: 5,
      );

      _orcamentosMesStream = stream.isBroadcast
          ? stream
          : stream.asBroadcastStream();
    } catch (_) {
      _orcamentosMesStream = Stream<List<OrcamentoCategoriaResumo>>.value(
        const <OrcamentoCategoriaResumo>[],
      ).asBroadcastStream();
    }
  }

  Stream<bool> _mostrarValoresDashboardStream() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<bool>.value(true);
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      final preferencias =
          (data['preferencias'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final value = preferencias['mostrarValoresDashboard'];
      return value is! bool || value;
    });
  }

  Future<void> _selecionarMesEspecifico() async {
    final base = _controller.mesEspecifico ?? DateTime.now();
    final data = await showDatePicker(
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
      _controller.selecionarMes(data);
    });
  }

  Future<void> _exportarRelatorioMensal() async {
    if (_exportandoRelatorio) {
      return;
    }

    if (kIsWeb) {
      AppFeedback.showError(
        context,
        'Exportação de arquivo indisponível no navegador nesta versão.',
      );
      return;
    }

    setState(() => _exportandoRelatorio = true);
    try {
      final referencia = _controller.mesReferenciaExportacao(DateTime.now());

      if (widget.exportadorRelatorio != null) {
        await widget.exportadorRelatorio!(referencia);
        if (mounted) {
          AppFeedback.showSuccess(context, 'Relatório PDF gerado com sucesso.');
        }
        return;
      }

      final relatorio = await _db.buscarRelatorioMensal(referencia);
      final exportado = await _reportExportService.gerarRelatorioMensal(
        relatorio,
      );

      final tempDir = await getTemporaryDirectory();
      final arquivo = File('${tempDir.path}/${exportado.nomeArquivoBase}.pdf');

      await arquivo.writeAsBytes(exportado.pdfBytes, flush: true);

      try {
        await SharePlus.instance.share(
          ShareParams(
            files: <XFile>[XFile(arquivo.path)],
            subject: 'Relatório mensal financeiro',
            text:
                'Relatório ${referencia.month.toString().padLeft(2, '0')}/${referencia.year}',
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
        AppFeedback.showSuccess(context, 'Relatório PDF gerado com sucesso.');
      }
    } catch (e) {
      if (mounted) {
        final exception = AppException.from(e);
        AppFeedback.showError(context, exception.message);
      }
    } finally {
      if (mounted) {
        setState(() => _exportandoRelatorio = false);
      }
    }
  }

  Future<void> _abrirDrillDownCategoria(
    DashboardCategoriaResumo categoria,
    bool mostrarValores,
  ) {
    return showDashboardDrillDownSheet(
      context: context,
      categoria: categoria,
      mostrarValores: mostrarValores,
      totalBase: _controller.memoResumo?.totalGastosPeriodo ?? 0,
      mesReferencia: _controller.mesEspecifico ?? DateTime.now(),
      onTapSaidasFiltradas: widget.onTapSaidasFiltradas,
    );
  }

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

    final semantic = theme.extension<AppSemanticColors>() ?? fallbackSemantic;

    return StreamBuilder<bool>(
      stream: _mostrarValoresDashboardStream(),
      initialData: true,
      builder: (context, mostrarValoresSnapshot) {
        final mostrarValores = mostrarValoresSnapshot.data ?? true;

        return StreamBuilder<DashboardResumo>(
          key: ValueKey<int>(_controller.retryTick),
          stream: _dashboardDataService.dashboardResumo,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const DashboardLoadingView();
            }

            if (snapshot.hasError) {
              final exception = AppException.from(snapshot.error);

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exception.message,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      const Text(
                        'Verifique conexão, permissões do Firebase e tente novamente.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      FilledButton.icon(
                        onPressed: () {
                          setState(_controller.tentarNovamente);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final agora = DateTime.now();
            final resumoBruto =
                snapshot.data ?? const DashboardResumo(<Gasto>[], <Conta>[]);
            final resumo = _controller.calcularResumoMemoizado(
              resumoBruto,
              agora,
            );

            return ColoredBox(
              color: theme.colorScheme.surface,
              child: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1100;
                    final isMedium = constraints.maxWidth >= 840;
                    final horizontalPadding = isWide
                        ? 28.0
                        : (isMedium ? 20.0 : 16.0);

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            20.0,
                            horizontalPadding,
                            28.0,
                          ),
                          children: [
                            DashboardHeaderSection(
                              tituloPeriodo: _controller.tituloPeriodo(agora),
                              insight: _controller.insightPrincipal(resumo),
                            ),
                            const SizedBox(height: 18),
                            DashboardPeriodFilters(
                              periodoSelecionado: _controller.periodo,
                              mesEspecifico: _controller.mesEspecifico,
                              onPeriodoChanged: (periodo) {
                                setState(() {
                                  _controller.selecionarPeriodo(periodo);
                                });
                              },
                              onSelecionarMes: _selecionarMesEspecifico,
                              onLimparMes: () {
                                setState(_controller.limparMesEspecifico);
                              },
                            ),
                            const SizedBox(height: 18),
                            DashboardEntry(
                              delayMs: 0,
                              child: DashboardHeroSaldoCard(
                                resumo: resumo,
                                mostrarValores: mostrarValores,
                                onTap: () {
                                  widget.onTapSaidasFiltradas?.call(
                                    DashboardDrillDownFilter(
                                      mesReferencia:
                                          _controller.mesEspecifico ??
                                          DateTime.now(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<List<Guardado>>(
                              stream: _db.guardados,
                              builder: (context, guardadosSnapshot) {
                                final guardados =
                                    guardadosSnapshot.data ?? <Guardado>[];
                                final referenciaGuardado = _controller
                                    .mesReferenciaGuardadoCard(agora);
                                final jaGuardadoMes = _controller
                                    .calcularJaGuardadoNoMes(
                                      guardados,
                                      referenciaGuardado,
                                    );

                                return DashboardEntry(
                                  delayMs: 20,
                                  child: DashboardGuardadoCard(
                                    resumo: resumo,
                                    jaGuardadoMes: jaGuardadoMes,
                                    referenciaMes: referenciaGuardado,
                                    mostrarValores: mostrarValores,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            DashboardEntry(
                              delayMs: 30,
                              child: DashboardPrevisaoCard(
                                resumoBruto: resumoBruto,
                                resumo: resumo,
                                agora: agora,
                                mostrarValores: mostrarValores,
                                orcamentosMesStream: _orcamentosMesStream,
                                recorrenciasService: _recorrenciasService,
                                previsaoFechamentoService:
                                    _previsaoFechamentoService,
                                insightsService: _insightsService,
                                referenciaMesRecorrencias: _controller
                                    .mesReferenciaRecorrencias(agora),
                                calcularRecorrenciasRestantesMes: _controller
                                    .calcularRecorrenciasRestantesMes,
                              ),
                            ),
                            const SizedBox(height: 14),
                            DashboardEntry(
                              delayMs: 50,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ComparativoChip(
                                      titulo:
                                          'Saldo vs ${resumo.comparativoLabel}',
                                      percentual: resumo.variacaoSaldo,
                                      positivoEhBom: true,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s12),
                                  Expanded(
                                    child: ComparativoChip(
                                      titulo:
                                          'Gastos vs ${resumo.comparativoLabel}',
                                      percentual: resumo.variacaoGastos,
                                      positivoEhBom: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            DashboardEntry(
                              delayMs: 100,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: MiniSummaryCard(
                                      titulo: 'Saídas',
                                      valor: resumo.totalGastosPeriodo,
                                      cor: semantic.error,
                                      icone: Icons.arrow_downward_rounded,
                                      mostrarValores: mostrarValores,
                                      onTap: () {
                                        widget.onTapSaidasFiltradas?.call(
                                          DashboardDrillDownFilter(
                                            mesReferencia:
                                                _controller.mesEspecifico ??
                                                DateTime.now(),
                                          ),
                                        );
                                        if (widget.onTapSaidasFiltradas ==
                                            null) {
                                          widget.onTapSaidas?.call();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s12),
                                  Expanded(
                                    child: MiniSummaryCard(
                                      titulo: 'A receber',
                                      valor: resumo.totalPendente,
                                      cor: semantic.warning,
                                      icone: Icons.pending_actions_rounded,
                                      mostrarValores: mostrarValores,
                                      onTap: widget.onTapReceber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            DashboardEntry(
                              delayMs: 130,
                              child: DashboardExportCard(
                                exportandoRelatorio: _exportandoRelatorio,
                                onExportar: _exportarRelatorioMensal,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DashboardEntry(
                              delayMs: 150,
                              child: DashboardOrcamentosCard(
                                orcamentosMesStream: _orcamentosMesStream,
                              ),
                            ),
                            const SizedBox(height: 20),
                            DashboardEntry(
                              delayMs: 180,
                              child: DashboardCategoriasSection(
                                resumo: resumo,
                                periodoTitulo: _controller.tituloPeriodo(agora),
                                mostrarValores: mostrarValores,
                                onTapSaidas: widget.onTapSaidas,
                                onTapCategoria: (categoria) {
                                  _abrirDrillDownCategoria(
                                    categoria,
                                    mostrarValores,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
