import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:paga_o_que_me_deve/domain/models/cartao_credito.dart';
import 'package:paga_o_que_me_deve/domain/models/categoria_personalizada.dart';
import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/guardado.dart';
import 'package:paga_o_que_me_deve/domain/models/preferencias_novo_gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';

class DashboardResumo {

  const DashboardResumo(this.gastos, this.contas);
  final List<Gasto> gastos;
  final List<Conta> contas;
}

class ResultadoImportacaoGastos {

  const ResultadoImportacaoGastos({
    required this.importados,
    required this.duplicados,
  });
  final int importados;
  final int duplicados;
}

class PaginaGastosResultado {

  const PaginaGastosResultado({
    required this.gastos,
    required this.cursor,
    required this.temMais,
  });
  final List<Gasto> gastos;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool temMais;
}

class RelatorioMensalFinanceiro {

  const RelatorioMensalFinanceiro({
    required this.mesReferencia,
    required this.gastosMes,
    required this.contasPendentes,
    required this.totalPorCategoria,
  });
  final DateTime mesReferencia;
  final List<Gasto> gastosMes;
  final List<Conta> contasPendentes;
  final Map<CategoriaGasto, double> totalPorCategoria;

  double get totalGastos =>
      gastosMes.fold<double>(0, (total, gasto) => total + gasto.valor);

  double get totalPendencias =>
      contasPendentes.fold<double>(0, (total, conta) => total + conta.valor);
}

class SugestaoRecorrenciaDespesa {

  const SugestaoRecorrenciaDespesa({
    required this.periodicidade,
    required this.ocorrencias,
    required this.diaPreferencial,
    required this.valorMedio,
    required this.confianca,
  });
  final String periodicidade;
  final int ocorrencias;
  final int diaPreferencial;
  final double valorMedio;
  final double confianca;
}

abstract class FinanceRepository {
  Stream<List<Conta>> get contasAReceber;
  Stream<List<Gasto>> get meusGastos;
  Stream<DashboardResumo> get dashboardResumo;
  Stream<List<CartaoCredito>> get cartoesCredito;
  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao;
  Stream<List<CategoriaPersonalizada>> get categoriasPersonalizadas;
  Stream<List<Guardado>> get guardados;

  Future<void> adicionarRecebivel(Conta conta);
  Future<void> alternarStatusRecebivel(String id, bool statusAtual);
  Future<void> deletarRecebivel(String id);
  Future<void> atualizarRecebivel(Conta conta);
  Future<void> restaurarRecebivel(Conta conta);

  Future<void> salvarGuardado(Guardado guardado);
  Future<void> atualizarGuardado(Guardado guardado);
  Future<void> deletarGuardado(String id);

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
    required TipoGasto tipo, CategoriaGasto? categoriaPadrao,
    String? categoriaPersonalizadaId,
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
