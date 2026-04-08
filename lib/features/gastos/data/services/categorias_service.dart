import 'package:paga_o_que_me_deve/domain/models/categoria_personalizada.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/preferencias_novo_gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class CategoriasService {
  const CategoriasService(this._repository);

  final FinanceRepository _repository;

  Stream<List<CategoriaPersonalizada>> get categoriasPersonalizadas {
    return _repository.categoriasPersonalizadas;
  }

  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao {
    return _repository.regrasCategoriaImportacao;
  }

  Future<PreferenciasNovoGasto> carregarPreferenciasNovoGasto() {
    return _repository.carregarPreferenciasNovoGasto();
  }

  Future<void> salvarCategoriaPersonalizada(CategoriaPersonalizada categoria) {
    return _repository.salvarCategoriaPersonalizada(categoria);
  }

  Future<void> arquivarCategoriaPersonalizada(String id, bool arquivada) {
    return _repository.arquivarCategoriaPersonalizada(id, arquivada);
  }

  Future<void> alternarFavoritaCategoriaPersonalizada(
    String id,
    bool favorita,
  ) {
    return _repository.alternarFavoritaCategoriaPersonalizada(id, favorita);
  }

  Future<void> deletarCategoriaPersonalizada(String id) {
    return _repository.deletarCategoriaPersonalizada(id);
  }

  Future<bool> categoriaPersonalizadaEmUso(String id) {
    return _repository.categoriaPersonalizadaEmUso(id);
  }

  Future<void> salvarRegraCategoriaImportacao({
    required String termo,
    required CategoriaGasto categoria,
  }) {
    return _repository.salvarRegraCategoriaImportacao(
      termo: termo,
      categoria: categoria,
    );
  }
}
