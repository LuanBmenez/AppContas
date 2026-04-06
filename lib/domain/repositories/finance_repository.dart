import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/cartao_credito_model.dart';
import '../../models/conta_model.dart';
import '../../models/gasto_model.dart';
import '../../models/regra_categoria_importacao_model.dart';

class DashboardResumo {
  final List<Gasto> gastos;
  final List<Conta> contas;

  const DashboardResumo(this.gastos, this.contas);
}

class ResultadoImportacaoGastos {
  final int importados;
  final int duplicados;

  const ResultadoImportacaoGastos({
    required this.importados,
    required this.duplicados,
  });
}

class PaginaGastosResultado {
  final List<Gasto> gastos;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool temMais;

  const PaginaGastosResultado({
    required this.gastos,
    required this.cursor,
    required this.temMais,
  });
}

class RelatorioMensalFinanceiro {
  final DateTime mesReferencia;
  final List<Gasto> gastosMes;
  final List<Conta> contasPendentes;
  final Map<CategoriaGasto, double> totalPorCategoria;

  const RelatorioMensalFinanceiro({
    required this.mesReferencia,
    required this.gastosMes,
    required this.contasPendentes,
    required this.totalPorCategoria,
  });

  double get totalGastos => gastosMes.fold<double>(
    0,
    (total, gasto) => total + gasto.valor,
  );

  double get totalPendencias => contasPendentes.fold<double>(
    0,
    (total, conta) => total + conta.valor,
  );
}

abstract class FinanceRepository {
  Stream<List<Conta>> get contasAReceber;
  Stream<List<Gasto>> get meusGastos;
  Stream<DashboardResumo> get dashboardResumo;
  Stream<List<CartaoCredito>> get cartoesCredito;
  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao;

  Future<void> adicionarRecebivel(Conta conta);
  Future<void> alternarStatusRecebivel(String id, bool statusAtual);
  Future<void> deletarRecebivel(String id);
  Future<void> atualizarRecebivel(Conta conta);
  Future<void> restaurarRecebivel(Conta conta);

  Future<void> adicionarGasto(Gasto gasto);
  Future<ResultadoImportacaoGastos> importarGastosComDeduplicacao(
    List<Gasto> gastos,
  );
  Future<int> contarDuplicadosPorHash(List<String> hashes);
  Stream<List<Gasto>> streamGastosPorPeriodo({
    required DateTime inicio,
    required DateTime fimExclusivo,
    int? limite,
  });
  Future<PaginaGastosResultado> buscarGastosPorPeriodoPaginado({
    required DateTime inicio,
    required DateTime fimExclusivo,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    int limite,
  });
  Future<void> deletarGasto(String id);
  Future<void> atualizarGasto(Gasto gasto);
  Future<void> restaurarGasto(Gasto gasto);

  Future<void> adicionarCartaoCredito(CartaoCredito cartao);
  Future<void> deletarCartaoCredito(String id);

  Future<void> salvarRegraCategoriaImportacao({
    required String termo,
    required CategoriaGasto categoria,
  });

  Future<RelatorioMensalFinanceiro> buscarRelatorioMensal(DateTime referencia);
}
