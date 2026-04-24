import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';

class DashboardScreenController {
  DashboardScreenController({required DashboardSummaryService summaryService})
    : _summaryService = summaryService;

  final DashboardSummaryService _summaryService;

  DashboardPeriodoRapido periodo = DashboardPeriodoRapido.mes;
  DateTime? mesEspecifico;
  int retryTick = 0;

  String _memoKey = '';
  DashboardResumoCalculado? _memoResumo;

  DashboardResumoCalculado? get memoResumo => _memoResumo;

  void selecionarPeriodo(DashboardPeriodoRapido novoPeriodo) {
    periodo = novoPeriodo;
    mesEspecifico = null;
  }

  void selecionarMes(DateTime data) {
    mesEspecifico = DateTime(data.year, data.month);
  }

  void limparMesEspecifico() {
    mesEspecifico = null;
  }

  void tentarNovamente() {
    retryTick++;
  }

  String tituloPeriodo(DateTime agora) {
    if (mesEspecifico != null) {
      return 'Mês de ${AppFormatters.nomeMes(mesEspecifico!.month)}';
    }

    switch (periodo) {
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

  ({DateTime inicio, DateTime fimExclusivo}) faixaSelecionada(DateTime agora) {
    if (mesEspecifico != null) {
      final inicio = DateTime(
        mesEspecifico!.year,
        mesEspecifico!.month,
      );
      final fimExclusivo = DateTime(
        mesEspecifico!.year,
        mesEspecifico!.month + 1,
      );
      return (inicio: inicio, fimExclusivo: fimExclusivo);
    }

    return _summaryService.faixaAtual(periodo, agora);
  }

  DateTime mesReferenciaExportacao(DateTime agora) {
    final faixa = faixaSelecionada(agora);
    return DateTime(faixa.inicio.year, faixa.inicio.month);
  }

  DateTime mesReferenciaRecorrencias(DateTime agora) {
    return mesEspecifico == null
        ? DateTime(agora.year, agora.month)
        : DateTime(mesEspecifico!.year, mesEspecifico!.month);
  }

  DateTime mesReferenciaGuardadoCard(DateTime agora) {
    if (mesEspecifico != null) {
      return DateTime(mesEspecifico!.year, mesEspecifico!.month);
    }
    return DateTime(agora.year, agora.month);
  }

  int contarOcorrenciasRestantesNoMes(
    RecorrenciaAtiva recorrencia,
    DateTime referenciaMes,
  ) {
    return recorrencia.ativosDesdeHoje.where((gasto) {
      return gasto.data.year == referenciaMes.year &&
          gasto.data.month == referenciaMes.month;
    }).length;
  }

  double calcularRecorrenciasRestantesMes(
    List<RecorrenciaAtiva> recorrencias,
    DateTime referenciaMes,
  ) {
    // Refatorado com fold para não usar variáveis mutáveis externas
    return recorrencias.fold<double>(0, (total, recorrencia) {
      final ocorrencias = contarOcorrenciasRestantesNoMes(
        recorrencia,
        referenciaMes,
      );
      return total + (recorrencia.valorMedio * ocorrencias);
    });
  }

  double calcularJaGuardadoNoMes(
    List<Guardado> guardados,
    DateTime referenciaMes,
  ) {
    final competencia = Guardado.competenciaFromDate(referenciaMes);

    // Refatorado com where e fold para ser idiomático em Dart
    return guardados
        .where(
          (item) =>
              item.competencia == competencia &&
              item.tipoMovimentacao == GuardadoTipoMovimentacao.aporte,
        )
        .fold<double>(0, (total, item) => total + item.valor);
  }

  String insightPrincipal(DashboardResumoCalculado resumo) {
    final lider = resumo.categoriaMaisGasta;
    if (lider == null) {
      return 'Sem gastos no período. Registre uma saída para gerar insights.';
    }

    final participacao = resumo.totalGastosPeriodo <= 0
        ? 0
        : (lider.valor / resumo.totalGastosPeriodo) * 100;

    return '${lider.label} concentra ${participacao.toStringAsFixed(1)}% das saídas. Considere revisar esse grupo primeiro.';
  }

  DashboardResumoCalculado calcularResumoMemoizado(
    DashboardResumo bruto,
    DateTime agora,
  ) {
    final faixa = faixaSelecionada(agora);

    // CORREÇÃO CRÍTICA DE CACHE: identityHashCode previne o bug de edição!
    final chave = [
      identityHashCode(bruto),
      faixa.inicio.millisecondsSinceEpoch,
      faixa.fimExclusivo.millisecondsSinceEpoch,
      periodo.name,
      mesEspecifico?.millisecondsSinceEpoch ?? 0,
    ].join('|');

    if (_memoResumo != null && _memoKey == chave) {
      return _memoResumo!;
    }

    final resumo = _summaryService.calcularResumo(
      resumo: bruto,
      periodo: periodo,
      inicioOverride: faixa.inicio,
      fimExclusivoOverride: faixa.fimExclusivo,
      agora: agora,
    );

    _memoKey = chave;
    _memoResumo = resumo;
    return resumo;
  }
}
