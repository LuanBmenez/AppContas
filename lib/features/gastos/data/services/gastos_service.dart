import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class GastosService {
  const GastosService(this._repository);

  final FinanceRepository _repository;

  Stream<List<Gasto>> get meusGastos => _repository.meusGastos;

  Stream<List<Gasto>> streamGastosPorPeriodo({
    required DateTime inicio,
    required DateTime fimExclusivo,
    int? limite,
  }) {
    return _repository.streamGastosPorPeriodo(
      inicio: inicio,
      fimExclusivo: fimExclusivo,
      limite: limite,
    );
  }

  Future<PaginaGastosResultado> buscarGastosPorPeriodoPaginado({
    required DateTime inicio,
    required DateTime fimExclusivo,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    int limite = 80,
  }) {
    return _repository.buscarGastosPorPeriodoPaginado(
      inicio: inicio,
      fimExclusivo: fimExclusivo,
      cursor: cursor,
      limite: limite,
    );
  }

  Future<void> adicionarGasto(Gasto gasto) {
    return _repository.adicionarGasto(gasto);
  }

  Future<void> atualizarGasto(Gasto gasto) {
    return _repository.atualizarGasto(gasto);
  }

  Future<void> restaurarGasto(Gasto gasto) {
    return _repository.restaurarGasto(gasto);
  }

  Future<void> deletarGasto(String id) {
    return _repository.deletarGasto(id);
  }

  Future<ResultadoImportacaoGastos> importarGastosComDeduplicacao(
    List<Gasto> gastos,
  ) {
    return _repository.importarGastosComDeduplicacao(gastos);
  }

  Future<int> contarDuplicadosPorHash(List<String> hashes) {
    return _repository.contarDuplicadosPorHash(hashes);
  }

  Future<void> registrarUsoNovoGasto({
    CategoriaGasto? categoriaPadrao,
    String? categoriaPersonalizadaId,
    required TipoGasto tipo,
  }) {
    return _repository.registrarUsoNovoGasto(
      categoriaPadrao: categoriaPadrao,
      categoriaPersonalizadaId: categoriaPersonalizadaId,
      tipo: tipo,
    );
  }

  Future<SugestaoRecorrenciaDespesa?> sugerirRecorrenciaPorTitulo(
    String titulo,
  ) {
    return _repository.sugerirRecorrenciaPorTitulo(titulo);
  }

  Future<int> contarPossiveisDuplicadosNoMesmoDia({
    required String titulo,
    required double valor,
    required DateTime data,
  }) async {
    final String tituloNormalizado = TextNormalizer.normalizeForSearch(
      titulo,
    ).trim().toLowerCase();

    if (tituloNormalizado.length < 3 || valor <= 0) {
      return 0;
    }

    final List<Gasto> gastos = await meusGastos.first;
    final DateTime dataBase = DateTime(data.year, data.month, data.day);

    int duplicados = 0;

    for (final Gasto gasto in gastos) {
      final DateTime dataGasto = DateTime(
        gasto.data.year,
        gasto.data.month,
        gasto.data.day,
      );

      if (dataGasto != dataBase) {
        continue;
      }

      if ((gasto.valor - valor).abs() > 0.001) {
        continue;
      }

      final String tituloExistente = TextNormalizer.normalizeForSearch(
        gasto.titulo,
      ).trim().toLowerCase();

      if (tituloExistente == tituloNormalizado) {
        duplicados++;
      }
    }

    return duplicados;
  }

  Future<int> salvarGastoComRecorrencias({
    required Gasto gastoBase,
    bool recorrenciaAtiva = false,
    int mesesFuturos = 0,
  }) async {
    await adicionarGasto(gastoBase);

    if (!recorrenciaAtiva || mesesFuturos <= 0) {
      return 1;
    }

    final List<Gasto> futuros = gerarRecorrenciasFuturas(
      base: gastoBase,
      mesesFuturos: mesesFuturos,
    );

    for (final Gasto gasto in futuros) {
      await adicionarGasto(gasto);
    }

    return 1 + futuros.length;
  }

  List<Gasto> gerarRecorrenciasFuturas({
    required Gasto base,
    required int mesesFuturos,
  }) {
    final List<Gasto> futuros = <Gasto>[];

    for (int i = 1; i <= mesesFuturos; i++) {
      futuros.add(
        base.copyWith(
          id: '',
          data: _adicionarMesesPreservandoDia(base.data, i),
          dataCompra: base.dataCompra == null
              ? null
              : _adicionarMesesPreservandoDia(base.dataCompra!, i),
          dataLancamento: base.dataLancamento == null
              ? null
              : _adicionarMesesPreservandoDia(base.dataLancamento!, i),
          hashImportacao: null,
        ),
      );
    }

    return futuros;
  }

  Future<void> deletarGastosEmLote(Iterable<Gasto> gastos) async {
    for (final Gasto gasto in gastos) {
      if (gasto.id.trim().isEmpty) {
        continue;
      }
      await deletarGasto(gasto.id);
    }
  }

  Future<void> atualizarCategoriaEmLote({
    required Iterable<Gasto> gastos,
    required CategoriaGasto categoria,
  }) async {
    for (final Gasto gasto in gastos) {
      await atualizarGasto(
        gasto.copyWith(
          categoria: categoria,
          categoriaPersonalizadaId: null,
          categoriaPersonalizadaNome: null,
          categoriaPersonalizadaCorValue: null,
          categoriaPersonalizadaIconeCodePoint: null,
        ),
      );
    }
  }

  Future<void> atualizarTipoEmLote({
    required Iterable<Gasto> gastos,
    required TipoGasto tipo,
  }) async {
    for (final Gasto gasto in gastos) {
      await atualizarGasto(gasto.copyWith(tipo: tipo));
    }
  }

  DateTime _adicionarMesesPreservandoDia(DateTime dataBase, int meses) {
    final int ano = dataBase.year + ((dataBase.month - 1 + meses) ~/ 12);
    final int mes = ((dataBase.month - 1 + meses) % 12) + 1;
    final int ultimoDiaMes = DateTime(ano, mes + 1, 0).day;
    final int dia = dataBase.day > ultimoDiaMes ? ultimoDiaMes : dataBase.day;

    return DateTime(ano, mes, dia);
  }
}
