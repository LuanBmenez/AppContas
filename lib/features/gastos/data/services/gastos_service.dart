import 'package:cloud_firestore/cloud_firestore.dart';
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
}
