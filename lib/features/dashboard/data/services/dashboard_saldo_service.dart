import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/recebimento.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/domain/repositories/recebimentos_repository.dart';
import 'package:rxdart/rxdart.dart';

class DashboardSaldoService {
  DashboardSaldoService({
    required this.recebimentosRepository,
    required this.financeRepository,
  });
  final RecebimentosRepository recebimentosRepository;
  final FinanceRepository financeRepository;

  /// Calcula o resumo mensal, incluindo saldo acumulado
  Stream<ResumoMensalDashboard> resumoMensal(
    String competenciaMesAnterior,
    String competenciaMesAtual,
  ) {
    final recebimentosAnteriorStream = recebimentosRepository
        .streamRecebimentosPorMes(competenciaMesAnterior);
    final recebimentosAtualStream = recebimentosRepository
        .streamRecebimentosPorMes(competenciaMesAtual);

    // Parse competenciaMesAtual para obter o período do mês
    final partes = competenciaMesAtual.split('-');
    final ano = int.parse(partes[0]);
    final mes = int.parse(partes[1]);
    final inicio = DateTime(ano, mes);
    final fimExclusivo = DateTime(ano, mes + 1);

    final despesasAtualStream = financeRepository.streamGastosPorPeriodo(
      inicio: inicio,
      fimExclusivo: fimExclusivo,
    );

    return Rx.combineLatest3<
      List<Recebimento>,
      List<Recebimento>,
      List<Gasto>,
      ResumoMensalDashboard
    >(
      recebimentosAnteriorStream,
      recebimentosAtualStream,
      despesasAtualStream,
      (recebimentosAnt, recebimentosAtual, despesasAtual) {
        final totalRecebidoAnt = recebimentosAnt
            .where((r) => r.status == StatusRecebimento.recebido)
            .fold<double>(0.0, (s, r) => s + r.valor);

        final totalRecebidoAtual = recebimentosAtual
            .where((r) => r.status == StatusRecebimento.recebido)
            .fold<double>(0.0, (s, r) => s + r.valor);

        final totalPrevistoAtual = recebimentosAtual.fold<double>(
          0.0,
          (s, r) => s + r.valor,
        );

        final totalPendenteAtual = recebimentosAtual
            .where((r) => r.status != StatusRecebimento.recebido)
            .fold<double>(0.0, (s, r) => s + r.valor);

        final totalDespesasAtual = despesasAtual.fold<double>(
          0.0,
          (s, g) => s + g.valor,
        );

        final saldoInicial = totalRecebidoAnt;
        final saldoFinal =
            saldoInicial + totalRecebidoAtual - totalDespesasAtual;

        return ResumoMensalDashboard(
          saldoInicial: saldoInicial,
          totalRecebido: totalRecebidoAtual,
          totalDespesas: totalDespesasAtual,
          saldoFinal: saldoFinal,
          totalPrevisto: totalPrevistoAtual,
          totalPendente: totalPendenteAtual,
        );
      },
    );
  }
}

class ResumoMensalDashboard {
  ResumoMensalDashboard({
    required this.saldoInicial,
    required this.totalRecebido,
    required this.totalDespesas,
    required this.saldoFinal,
    required this.totalPrevisto,
    required this.totalPendente,
  });
  final double saldoInicial;
  final double totalRecebido;
  final double totalDespesas;
  final double saldoFinal;
  final double totalPrevisto;
  final double totalPendente;
}
