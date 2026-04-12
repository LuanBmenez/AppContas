import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/dashboard_data_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/dashboard_summary_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/previsao_fechamento_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/report_export_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/domain/models/previsao_fechamento_mes.dart';
import 'package:paga_o_que_me_deve/features/dashboard/presentation/widgets/dashboard_loading_view.dart';
import 'package:paga_o_que_me_deve/features/insights/insights.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/orcamentos.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/data/services/recorrencias_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.db,
    this.exportadorRelatorio,
    this.orcamentosMesStreamOverride,
    this.onTapSaidas,
    this.onTapReceber,
    this.onTapSaidasFiltradas,
  });

  final FinanceRepository db;
  final Future<void> Function(DateTime referencia)? exportadorRelatorio;
  final Stream<List<OrcamentoCategoriaResumo>>? orcamentosMesStreamOverride;
  final VoidCallback? onTapSaidas;
  final VoidCallback? onTapReceber;
  final ValueChanged<DashboardDrillDownFilter>? onTapSaidasFiltradas;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardDataService _dashboardDataService;
  late final Stream<List<OrcamentoCategoriaResumo>> _orcamentosMesStream;
  late final RecorrenciasService _recorrenciasService;

  final DashboardSummaryService _summaryService = DashboardSummaryService();
  final PrevisaoFechamentoService _previsaoFechamentoService =
      const PrevisaoFechamentoService();
  final InsightsService _insightsService = const InsightsService();
  final ReportExportService _reportExportService = const ReportExportService();

  DashboardPeriodoRapido _periodo = DashboardPeriodoRapido.mes;
  DateTime? _mesEspecifico;
  bool _exportandoRelatorio = false;
  int _retryTick = 0;

  String _memoKey = '';
  DashboardResumoCalculado? _memoResumo;

  @override
  void initState() {
    super.initState();
    _dashboardDataService = DashboardDataService(widget.db);
    _recorrenciasService = RecorrenciasService(repository: widget.db);

    final Stream<List<OrcamentoCategoriaResumo>>? streamOverride =
        widget.orcamentosMesStreamOverride;

    if (streamOverride != null) {
      _orcamentosMesStream = streamOverride.isBroadcast
          ? streamOverride
          : streamOverride.asBroadcastStream();
      return;
    }

    try {
      final OrcamentosService orcamentosService = OrcamentosService(
        repository: widget.db,
      );
      final Stream<List<OrcamentoCategoriaResumo>> stream = orcamentosService
          .calcularResumoPorCategoria(DateTime.now(), limite: 5);

      _orcamentosMesStream = stream.isBroadcast
          ? stream
          : stream.asBroadcastStream();
    } catch (_) {
      _orcamentosMesStream = Stream<List<OrcamentoCategoriaResumo>>.value(
        const <OrcamentoCategoriaResumo>[],
      ).asBroadcastStream();
    }
  }

  DateTime _mesReferenciaRecorrencias(DateTime agora) {
    return _mesEspecifico == null
        ? DateTime(agora.year, agora.month, 1)
        : DateTime(_mesEspecifico!.year, _mesEspecifico!.month, 1);
  }

  int _contarOcorrenciasRestantesNoMes(
    RecorrenciaAtiva recorrencia,
    DateTime referenciaMes,
  ) {
    return recorrencia.ativosDesdeHoje.where((gasto) {
      return gasto.data.year == referenciaMes.year &&
          gasto.data.month == referenciaMes.month;
    }).length;
  }

  double _calcularRecorrenciasRestantesMes(
    List<RecorrenciaAtiva> recorrencias,
    DateTime referenciaMes,
  ) {
    double total = 0;

    for (final RecorrenciaAtiva recorrencia in recorrencias) {
      final int ocorrencias = _contarOcorrenciasRestantesNoMes(
        recorrencia,
        referenciaMes,
      );
      total += recorrencia.valorMedio * ocorrencias;
    }

    return total;
  }

  Widget _buildOrcamentosMesCard(ThemeData theme) {
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
              stream: _orcamentosMesStream,
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
                          onPressed: () =>
                              context.push(AppRoutes.orcamentosPath),
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
      return 'Firestore sem permissão ou desativado no projeto.\n'
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
      _mesEspecifico?.millisecondsSinceEpoch ?? 0,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final double totalBase = _memoResumo?.totalGastosPeriodo ?? 0;
        final double percentual = totalBase <= 0
            ? 0
            : (categoria.valor / totalBase) * 100;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: categoria.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(categoria.icon, color: categoria.color),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        categoria.label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'Valor: ${AppFormatters.moeda(categoria.valor)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Participação: ${percentual.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),
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
                    icon: const Icon(Icons.open_in_new_rounded),
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
        'Exportação de arquivo indisponível no navegador nesta versão.',
      );
      return;
    }

    setState(() => _exportandoRelatorio = true);
    try {
      final DateTime referencia = _mesReferenciaExportacao(DateTime.now());

      if (widget.exportadorRelatorio != null) {
        await widget.exportadorRelatorio!(referencia);
        if (mounted) {
          AppFeedback.showSuccess(context, 'Relatório PDF gerado com sucesso.');
        }
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
        AppFeedback.showError(context, 'Falha ao exportar relatório: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _exportandoRelatorio = false);
      }
    }
  }

  Widget _buildHeader(ThemeData theme, DateTime agora) {
    final String insight = _memoResumo == null
        ? ''
        : _insightPrincipal(_memoResumo!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo financeiro',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _tituloPeriodo(agora),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (insight.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            insight,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPeriodChip(ThemeData theme, DashboardPeriodoRapido periodo) {
    final bool selecionado = _periodo == periodo && _mesEspecifico == null;

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
      onSelected: (_) {
        setState(() {
          _periodo = periodo;
          _mesEspecifico = null;
        });
      },
    );
  }

  Widget _buildActionPill({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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

  Widget _buildHeroSaldoCard(ThemeData theme, DashboardResumoCalculado resumo) {
    const AppSemanticColors fallbackSemantic = AppSemanticColors(
      success: Color(0xFF0F9D7A),
      successContainer: Color(0xFFE5F6F2),
      warning: Color(0xFFC26A00),
      warningContainer: Color(0xFFFFEED9),
      error: Color(0xFFD64545),
      errorContainer: Color(0xFFFDE8E8),
    );

    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? fallbackSemantic;
    final bool saldoPositivo = resumo.saldoPositivo;
    final List<Color> colors = saldoPositivo
        ? [semantic.success, semantic.success.withValues(alpha: 0.85)]
        : [semantic.error, semantic.error.withValues(alpha: 0.85)];

    return _DashboardEntry(
      delayMs: 0,
      child: Container(
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
          onTap: () {
            widget.onTapSaidasFiltradas?.call(
              DashboardDrillDownFilter(
                mesReferencia: _mesEspecifico ?? DateTime.now(),
              ),
            );
          },
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
                AppFormatters.moeda(resumo.saldo),
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
      ),
    );
  }

  DateTime _mesReferenciaGuardadoCard(DateTime agora) {
    if (_mesEspecifico != null) {
      return DateTime(_mesEspecifico!.year, _mesEspecifico!.month, 1);
    }
    return DateTime(agora.year, agora.month, 1);
  }

  double _calcularJaGuardadoNoMes(
    List<Guardado> guardados,
    DateTime referenciaMes,
  ) {
    final String competencia = Guardado.competenciaFromDate(referenciaMes);
    double total = 0;

    for (final Guardado item in guardados) {
      if (item.competencia != competencia) {
        continue;
      }
      if (item.tipoMovimentacao != GuardadoTipoMovimentacao.aporte) {
        continue;
      }
      total += item.valor;
    }

    return total;
  }

  Widget _buildSobraGuardadoCard(
    ThemeData theme,
    DashboardResumoCalculado resumo, {
    required double jaGuardadoMes,
    required DateTime referenciaMes,
  }) {
    final bool temSobra = resumo.saldo > 0;
    final double valorGuardavel = temSobra ? resumo.saldo : 0;
    final String nomeMes = AppFormatters.nomeMes(referenciaMes.month);

    return _DashboardEntry(
      delayMs: 20,
      child: Material(
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
                        AppFormatters.moeda(valorGuardavel),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Já guardado em $nomeMes: ${AppFormatters.moeda(jaGuardadoMes)}',
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
      ),
    );
  }

  Widget _buildExportCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _exportandoRelatorio
                  ? 'Gerando e compartilhando relatório...'
                  : 'Exportar relatório PDF',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _exportandoRelatorio ? null : _exportarRelatorioMensal,
            child: Text(_exportandoRelatorio ? 'Gerando...' : 'Exportar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrevisaoMesCard(
    ThemeData theme,
    DashboardResumo resumoBruto,
    DashboardResumoCalculado resumo,
    DateTime agora,
  ) {
    return StreamBuilder<List<OrcamentoCategoriaResumo>>(
      stream: _orcamentosMesStream,
      builder: (context, snapshotOrcamentos) {
        final List<OrcamentoCategoriaResumo> orcamentos =
            snapshotOrcamentos.data ?? <OrcamentoCategoriaResumo>[];

        final PrevisaoFechamentoMes previsao = _previsaoFechamentoService
            .calcular(
              resumo: resumoBruto,
              orcamentosCategoria: orcamentos,
              agora: agora,
            );

        final List<PrevisaoCategoriaRisco> riscos = previsao.categoriasComRisco
            .take(3)
            .toList();

        return StreamBuilder<List<RecorrenciaAtiva>>(
          stream: _recorrenciasService.streamRecorrenciasAtivas(),
          builder: (context, snapshotRecorrencias) {
            final List<RecorrenciaAtiva> recorrencias =
                snapshotRecorrencias.data ?? <RecorrenciaAtiva>[];

            final DateTime referenciaMes = _mesReferenciaRecorrencias(agora);

            final double recorrenciasRestantesCorrigidas =
                _calcularRecorrenciasRestantesMes(recorrencias, referenciaMes);

            final double projecaoTotalCorrigida =
                previsao.projecaoTotal -
                previsao.recorrenciasRestantes +
                recorrenciasRestantesCorrigidas;

            final List<InsightItem> insights = _insightsService.gerarInsights(
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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.13,
                                ),
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.06,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fechamento previsto',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              Text(
                                AppFormatters.moeda(projecaoTotalCorrigida),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s6),
                              Text(
                                'Mantendo o ritmo atual, você deve fechar o mês em ${AppFormatters.moeda(projecaoTotalCorrigida)}.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
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
                                AppFormatters.moeda(
                                  recorrenciasRestantesCorrigidas,
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                recorrenciasRestantesCorrigidas > 0
                                    ? 'Ainda faltam ${AppFormatters.moeda(recorrenciasRestantesCorrigidas)} em despesas recorrentes previstas.'
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
                                child: _PrevisaoCategoriaRiscoItem(
                                  risco: risco,
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const AppSemanticColors fallbackSemantic = AppSemanticColors(
      success: Color(0xFF0F9D7A),
      successContainer: Color(0xFFE5F6F2),
      warning: Color(0xFFC26A00),
      warningContainer: Color(0xFFFFEED9),
      error: Color(0xFFD64545),
      errorContainer: Color(0xFFFDE8E8),
    );

    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? fallbackSemantic;

    return StreamBuilder<DashboardResumo>(
      key: ValueKey<int>(_retryTick),
      stream: _dashboardDataService.dashboardResumo,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DashboardLoadingView();
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

        return Container(
          color: theme.colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth >= 1100;
                final bool isMedium = constraints.maxWidth >= 840;
                final double horizontalPadding = isWide
                    ? 28
                    : (isMedium ? 20 : 16);

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        20,
                        horizontalPadding,
                        28,
                      ),
                      children: [
                        _buildHeader(theme, agora),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: DashboardPeriodoRapido.values
                              .map(
                                (periodo) => _buildPeriodChip(theme, periodo),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildActionPill(
                              theme: theme,
                              icon: Icons.calendar_month_outlined,
                              label: _mesEspecifico == null
                                  ? 'Escolher mês'
                                  : AppFormatters.mesAno(_mesEspecifico!),
                              onTap: _selecionarMesEspecifico,
                            ),
                            if (_mesEspecifico != null)
                              InputChip(
                                label: const Text('Mês específico'),
                                onDeleted: _limparMesEspecifico,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildHeroSaldoCard(theme, resumo),
                        const SizedBox(height: 12),
                        StreamBuilder<List<Guardado>>(
                          stream: widget.db.guardados,
                          builder: (context, guardadosSnapshot) {
                            final List<Guardado> guardados =
                                guardadosSnapshot.data ?? <Guardado>[];
                            final DateTime referenciaGuardado =
                                _mesReferenciaGuardadoCard(agora);
                            final double jaGuardadoMes =
                                _calcularJaGuardadoNoMes(
                                  guardados,
                                  referenciaGuardado,
                                );

                            return _buildSobraGuardadoCard(
                              theme,
                              resumo,
                              jaGuardadoMes: jaGuardadoMes,
                              referenciaMes: referenciaGuardado,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _DashboardEntry(
                          delayMs: 30,
                          child: _buildPrevisaoMesCard(
                            theme,
                            resumoBruto,
                            resumo,
                            agora,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DashboardEntry(
                          delayMs: 50,
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
                        _DashboardEntry(
                          delayMs: 100,
                          child: Row(
                            children: [
                              Expanded(
                                child: _MiniSummaryCard(
                                  titulo: 'Saídas',
                                  valor: resumo.totalGastosPeriodo,
                                  cor: semantic.error,
                                  icone: Icons.arrow_downward_rounded,
                                  onTap: () {
                                    widget.onTapSaidasFiltradas?.call(
                                      DashboardDrillDownFilter(
                                        mesReferencia:
                                            _mesEspecifico ?? DateTime.now(),
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
                                  titulo: 'A receber',
                                  valor: resumo.totalPendente,
                                  cor: semantic.warning,
                                  icone: Icons.pending_actions_rounded,
                                  onTap: widget.onTapReceber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DashboardEntry(
                          delayMs: 130,
                          child: _buildExportCard(theme),
                        ),
                        const SizedBox(height: 16),
                        _DashboardEntry(
                          delayMs: 150,
                          child: _buildOrcamentosMesCard(theme),
                        ),
                        const SizedBox(height: 20),
                        _DashboardEntry(
                          delayMs: 180,
                          child: Card(
                            elevation: 0,
                            color: theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                              side: BorderSide(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.08,
                                ),
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
                                    'Total analisado: ${AppFormatters.moeda(resumo.totalGastosPeriodo)} • ${resumo.categoriasOrdenadas.length} categorias ativas',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  if (resumo.categoriasOrdenadas.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.s16,
                                        vertical: AppSpacing.s24,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: theme
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.pie_chart_outline_rounded,
                                            size: 42,
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.35),
                                          ),
                                          const SizedBox(
                                            height: AppSpacing.s12,
                                          ),
                                          const Text(
                                            'Sem gastos no período para montar o gráfico.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.s4),
                                          Text(
                                            'Adicione gastos para ver a distribuição por categoria.',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(
                                            height: AppSpacing.s16,
                                          ),
                                          Wrap(
                                            spacing: AppSpacing.s10,
                                            runSpacing: AppSpacing.s10,
                                            alignment: WrapAlignment.center,
                                            children: [
                                              FilledButton.icon(
                                                onPressed: () {
                                                  if (widget.onTapSaidas !=
                                                      null) {
                                                    widget.onTapSaidas!.call();
                                                    return;
                                                  }
                                                  context.push(
                                                    AppRoutes.novoGastoPath,
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.add_rounded,
                                                ),
                                                label: const Text(
                                                  'Adicionar gasto',
                                                ),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => context.push(
                                                  AppRoutes.importarPath,
                                                ),
                                                icon: const Icon(
                                                  Icons.upload_file_outlined,
                                                ),
                                                label: const Text(
                                                  'Importar CSV',
                                                ),
                                              ),
                                            ],
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
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final Widget
                                      cardLider = _InsightResumoCard(
                                        titulo: 'Categoria líder',
                                        categoria: resumo.categoriaMaisGasta,
                                        valor:
                                            resumo.categoriaMaisGasta?.valor ??
                                            0,
                                      );

                                      final Widget
                                      cardMenor = _InsightResumoCard(
                                        titulo: 'Menor participação',
                                        categoria: resumo.categoriaMenosGasta,
                                        valor:
                                            resumo.categoriaMenosGasta?.valor ??
                                            0,
                                      );

                                      final Widget cardAtivas =
                                          _InsightResumoCard(
                                            titulo: 'Categorias ativas',
                                            valor: resumo
                                                .categoriasOrdenadas
                                                .length
                                                .toDouble(),
                                            labelUnico: true,
                                          );

                                      if (constraints.maxWidth < 820) {
                                        return Column(
                                          children: [
                                            cardLider,
                                            const SizedBox(
                                              height: AppSpacing.s12,
                                            ),
                                            cardMenor,
                                            const SizedBox(
                                              height: AppSpacing.s12,
                                            ),
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
  }
}

class _PrevisaoCategoriaRiscoItem extends StatelessWidget {
  const _PrevisaoCategoriaRiscoItem({required this.risco});

  final PrevisaoCategoriaRisco risco;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double percentual = risco.percentualPrevistoOrcamento;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: risco.categoria.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: risco.categoria.color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                risco.categoria.icon,
                size: 16,
                color: risco.categoria.color,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  risco.categoria.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${percentual.toStringAsFixed(0)}% do orçamento',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Previsto ${AppFormatters.moeda(risco.projecaoFimMes)} / orçamento ${AppFormatters.moeda(risco.orcamentoLimite)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cor.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icone, size: 20, color: cor),
                ),
                const SizedBox(height: 14),
                Text(
                  titulo,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppFormatters.moeda(valor),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toque para ver detalhes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
    final ThemeData theme = Theme.of(context);
    const AppSemanticColors fallbackSemantic = AppSemanticColors(
      success: Color(0xFF0F9D7A),
      successContainer: Color(0xFFE5F6F2),
      warning: Color(0xFFC26A00),
      warningContainer: Color(0xFFFFEED9),
      error: Color(0xFFD64545),
      errorContainer: Color(0xFFFDE8E8),
    );
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? fallbackSemantic;

    final bool subiu = percentual >= 0;
    final bool bom = positivoEhBom ? subiu : !subiu;
    final Color cor = bom ? semantic.success : semantic.error;
    final IconData icone = subiu
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 18),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${percentual.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final bool reduzirAnimacoes =
        (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);

    if (reduzirAnimacoes) {
      return child;
    }

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
    final ThemeData theme = Theme.of(context);
    final Color cor = categoria?.color ?? theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (labelUnico)
            Text(
              valor.toInt().toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            )
          else ...[
            Row(
              children: [
                if (categoria != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(categoria!.icon, size: 14, color: cor),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                ],
                Expanded(
                  child: Text(
                    categoria?.label ?? 'Sem dados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              AppFormatters.moeda(valor),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
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
    final ThemeData theme = Theme.of(context);
    final List<DashboardCategoriaResumo> barras = data.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.05),
            theme.colorScheme.secondary.withValues(alpha: 0.025),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      AppFormatters.moeda(total),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${data.length} categorias',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s18),
          ...barras.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s14),
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
    final ThemeData theme = Theme.of(context);
    final double percentual = total <= 0 ? 0 : categoria.valor / total;
    final String percentualTexto = '${(percentual * 100).toStringAsFixed(1)}%';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: categoria.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoria.icon,
                      size: 16,
                      color: categoria.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(
                      categoria.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    percentualTexto,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    AppFormatters.moeda(categoria.valor),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
      ),
    );
  }
}
