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

  /// Calcula o resumo mensal reativo, incluindo o saldo transitado do mês anterior
  Stream<ResumoMensalDashboard> resumoMensal(
    String competenciaMesAnterior,
    String competenciaMesAtual,
  ) {
    // 1. Datas do Mês Atual
    final inicioAtual = _inicioMesPorCompetencia(competenciaMesAtual);
    final fimAtualExclusivo = DateTime(inicioAtual.year, inicioAtual.month + 1);

    // 2. Datas do Mês Anterior
    final inicioAnterior = _inicioMesPorCompetencia(competenciaMesAnterior);
    final fimAnteriorExclusivo = DateTime(
      inicioAnterior.year,
      inicioAnterior.month + 1,
    );

    // 3. Streams de Recebimentos
    final recebimentosAnteriorStream = recebimentosRepository
        .streamRecebimentosPorMes(competenciaMesAnterior);
    final recebimentosAtualStream = recebimentosRepository
        .streamRecebimentosPorMes(competenciaMesAtual);

    // 4. Streams de Despesas (Agora puxamos também as do mês anterior!)
    final despesasAnteriorStream = financeRepository.streamGastosPorPeriodo(
      inicio: inicioAnterior,
      fimExclusivo: fimAnteriorExclusivo,
    );
    final despesasAtualStream = financeRepository.streamGastosPorPeriodo(
      inicio: inicioAtual,
      fimExclusivo: fimAtualExclusivo,
    );

    // Utilizamos combineLatest4 para juntar todos os fatores financeiros
    return Rx.combineLatest4<
      List<Recebimento>,
      List<Recebimento>,
      List<Gasto>,
      List<Gasto>,
      ResumoMensalDashboard
    >(
      recebimentosAnteriorStream,
      recebimentosAtualStream,
      despesasAtualStream,
      despesasAnteriorStream,
      (recebimentosAnt, recebimentosAtual, despesasAtual, despesasAnt) {
        // --- Contabilidade do Mês Anterior ---
        final totalRecebidoAnt = recebimentosAnt
            .where((r) => r.status == StatusRecebimento.recebido)
            .fold<double>(0.0, (s, r) => s + r.valor);

        final totalDespesasAnt = despesasAnt.fold<double>(
          0.0,
          (s, g) => s + g.valor,
        );

        // O verdadeiro Saldo Inicial é o que sobrou do mês passado!
        final saldoInicial = totalRecebidoAnt - totalDespesasAnt;

        // --- Contabilidade do Mês Atual ---
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

        // --- Resultado Final ---
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

  // Método helper extraído e blindado contra erros de parse
  static DateTime _inicioMesPorCompetencia(String competencia) {
    final partes = competencia.split('-');

    if (partes.length != 2) {
      // Fallback seguro em vez de crash
      return DateTime(DateTime.now().year, DateTime.now().month);
    }

    final ano = int.tryParse(partes[0]) ?? DateTime.now().year;
    final mes = int.tryParse(partes[1]) ?? DateTime.now().month;

    return DateTime(ano, mes);
  }
}

class ResumoMensalDashboard {
  const ResumoMensalDashboard({
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
