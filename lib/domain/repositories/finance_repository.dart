import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cartao_credito.dart';
import '../models/categoria_personalizada.dart';
import '../models/conta.dart';
import '../models/gasto.dart';
import '../models/preferencias_novo_gasto.dart';
import '../models/regra_categoria_importacao.dart';

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

  double get totalGastos =>
      gastosMes.fold<double>(0, (total, gasto) => total + gasto.valor);

  double get totalPendencias =>
      contasPendentes.fold<double>(0, (total, conta) => total + conta.valor);
}

class SugestaoRecorrenciaDespesa {
  final String periodicidade;
  final int ocorrencias;
  final int diaPreferencial;
  final double valorMedio;
  final double confianca;

  const SugestaoRecorrenciaDespesa({
    required this.periodicidade,
    required this.ocorrencias,
    required this.diaPreferencial,
    required this.valorMedio,
    required this.confianca,
  });
}

abstract class FinanceRepository {
  Stream<List<Conta>> get contasAReceber;
  Stream<List<Gasto>> get meusGastos;
  Stream<DashboardResumo> get dashboardResumo;
  Stream<List<CartaoCredito>> get cartoesCredito;
  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao;
  Stream<List<CategoriaPersonalizada>> get categoriasPersonalizadas;

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

  Future<void> salvarCategoriaPersonalizada(CategoriaPersonalizada categoria);
  Future<void> arquivarCategoriaPersonalizada(String id, bool arquivada);
  Future<void> alternarFavoritaCategoriaPersonalizada(String id, bool favorita);
  Future<void> deletarCategoriaPersonalizada(String id);
  Future<bool> categoriaPersonalizadaEmUso(String id);

  Future<PreferenciasNovoGasto> carregarPreferenciasNovoGasto();
  Future<void> registrarUsoNovoGasto({
    CategoriaGasto? categoriaPadrao,
    String? categoriaPersonalizadaId,
    required TipoGasto tipo,
  });

  Future<void> salvarRegraCategoriaImportacao({
    required String termo,
    required CategoriaGasto categoria,
  });
  Future<SugestaoRecorrenciaDespesa?> sugerirRecorrenciaPorTitulo(
    String titulo,
  );

  Future<RelatorioMensalFinanceiro> buscarRelatorioMensal(DateTime referencia);
}
