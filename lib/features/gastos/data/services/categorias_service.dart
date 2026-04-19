import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
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

  Future<void> aprenderRegraParaTitulo({
    required String titulo,
    required CategoriaGasto categoria,
  }) async {
    final termo = titulo.trim();
    if (termo.isEmpty) {
      return;
    }

    await salvarRegraCategoriaImportacao(termo: termo, categoria: categoria);
  }

  List<CategoriaPersonalizada> categoriasAtivas(
    List<CategoriaPersonalizada> categorias,
  ) {
    return categorias.where((categoria) => !categoria.arquivada).toList();
  }

  List<CategoriaPersonalizada> ordenarCategoriasAtivas(
    List<CategoriaPersonalizada> categorias,
  ) {
    final lista = categoriasAtivas(categorias);

    lista.sort((a, b) {
      if (a.favorita != b.favorita) {
        return a.favorita ? -1 : 1;
      }

      final uso = b.usoCount.compareTo(a.usoCount);
      if (uso != 0) {
        return uso;
      }

      return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });

    return lista;
  }

  List<CategoriaPersonalizada> filtrarCategoriasAtivas({
    required String textoBusca,
    required List<CategoriaPersonalizada> categorias,
  }) {
    final busca = TextNormalizer.normalizeForSearch(
      textoBusca,
    ).trim().toLowerCase();

    final base = ordenarCategoriasAtivas(
      categorias,
    );

    if (busca.isEmpty) {
      return base;
    }

    return base.where((categoria) {
      final nome = TextNormalizer.normalizeForSearch(
        categoria.nome,
      ).trim().toLowerCase();

      return nome.contains(busca);
    }).toList();
  }

  CategoriaPersonalizada? buscarCategoriaAtivaPorId({
    required List<CategoriaPersonalizada> categorias,
    required String? id,
  }) {
    if (id == null || id.trim().isEmpty) {
      return null;
    }

    for (final categoria in categoriasAtivas(
      categorias,
    )) {
      if (categoria.id == id) {
        return categoria;
      }
    }

    return null;
  }

  bool nomeCategoriaDuplicado({
    required String nome,
    required List<CategoriaPersonalizada> categorias,
    String? ignorarId,
  }) {
    final normalizado = TextNormalizer.normalizeForSearch(
      nome,
    ).trim().toLowerCase();

    if (normalizado.isEmpty) {
      return false;
    }

    for (final categoriaPadrao in CategoriaGasto.values) {
      final nomePadrao = TextNormalizer.normalizeForSearch(
        categoriaPadrao.label,
      ).trim().toLowerCase();

      if (nomePadrao == normalizado) {
        return true;
      }
    }

    for (final categoria in categoriasAtivas(
      categorias,
    )) {
      if (categoria.id == ignorarId) {
        continue;
      }

      final nomeExistente = TextNormalizer.normalizeForSearch(
        categoria.nome,
      ).trim().toLowerCase();

      if (nomeExistente == normalizado) {
        return true;
      }
    }

    return false;
  }
}
