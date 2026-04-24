import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
import 'package:paga_o_que_me_deve/domain/models/categoria_personalizada.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';

class CategoriaSugestaoResultado {
  const CategoriaSugestaoResultado({
    required this.categoriaPadrao,
    required this.categoriaPersonalizadaId,
  });

  final CategoriaGasto? categoriaPadrao;
  final String? categoriaPersonalizadaId;
}

class NovoGastoCategoriaController {
  static const Map<String, CategoriaGasto> _sugestoesPadrao =
      <String, CategoriaGasto>{
        'uber': CategoriaGasto.transporte,
        '99': CategoriaGasto.transporte,
        'ifood': CategoriaGasto.comida,
        'mercado': CategoriaGasto.comida,
        'farmacia': CategoriaGasto.saude,
        'drogaria': CategoriaGasto.saude,
        'aluguel': CategoriaGasto.moradia,
        'faculdade': CategoriaGasto.educacao,
        'curso': CategoriaGasto.educacao,
        'cinema': CategoriaGasto.entretenimento,
      };

  static CategoriaSugestaoResultado sugerirPorTitulo({
    required String titulo,
    required List<CategoriaPersonalizada> categoriasAtivas,
    List<RegraCategoriaImportacao> regrasAprendidas =
        const <RegraCategoriaImportacao>[],
  }) {
    final normalizado = TextNormalizer.normalizeForSearch(titulo).toLowerCase();

    if (normalizado.isEmpty) {
      return const CategoriaSugestaoResultado(
        categoriaPadrao: null,
        categoriaPersonalizadaId: null,
      );
    }

    // 1. Tentativa: Categorias Personalizadas (Código Funcional Limpo)
    final customMatch = categoriasAtivas.where((categoria) {
      final nome = TextNormalizer.normalizeForSearch(
        categoria.nome,
      ).toLowerCase();
      return nome.isNotEmpty && normalizado.contains(nome);
    }).firstOrNull;

    if (customMatch != null) {
      return CategoriaSugestaoResultado(
        categoriaPadrao: null,
        categoriaPersonalizadaId: customMatch.id,
      );
    }

    // 2. Tentativa: Regras Aprendidas do Utilizador
    final regrasOrdenadas = List<RegraCategoriaImportacao>.from(
      regrasAprendidas,
    )..sort((a, b) => b.termo.length.compareTo(a.termo.length));

    final regraMatch = regrasOrdenadas.where((regra) {
      final termo = TextNormalizer.normalizeForSearch(
        regra.termo,
      ).toLowerCase();
      return termo.isNotEmpty && normalizado.contains(termo);
    }).firstOrNull;

    if (regraMatch != null) {
      return CategoriaSugestaoResultado(
        categoriaPadrao: regraMatch.categoria,
        categoriaPersonalizadaId: null,
      );
    }

    // 3. Tentativa: Dicionário Estático de Palavras-Chave
    final padraoMatch = _sugestoesPadrao.entries
        .where((entry) => normalizado.contains(entry.key))
        .firstOrNull;

    return CategoriaSugestaoResultado(
      categoriaPadrao: padraoMatch?.value,
      categoriaPersonalizadaId: null,
    );
  }

  static List<CategoriaGasto> filtrarCategoriasPadrao(String textoBusca) {
    final busca = TextNormalizer.normalizeForSearch(textoBusca).toLowerCase();
    if (busca.isEmpty) return CategoriaGasto.values;

    return CategoriaGasto.values.where((categoria) {
      final nome = TextNormalizer.normalizeForSearch(
        categoria.label,
      ).toLowerCase();
      return nome.contains(busca);
    }).toList();
  }

  static List<CategoriaPersonalizada> filtrarCategoriasPersonalizadas(
    String textoBusca,
    List<CategoriaPersonalizada> categoriasAtivas,
  ) {
    final busca = TextNormalizer.normalizeForSearch(textoBusca).toLowerCase();
    final base = List<CategoriaPersonalizada>.from(categoriasAtivas);

    if (busca.isEmpty) {
      base.sort((a, b) {
        if (a.favorita != b.favorita) return a.favorita ? -1 : 1;
        return b.usoCount.compareTo(a.usoCount);
      });
      return base;
    }

    return base.where((categoria) {
      final nome = TextNormalizer.normalizeForSearch(
        categoria.nome,
      ).toLowerCase();
      return nome.contains(busca);
    }).toList();
  }

  static CategoriaPersonalizada? buscarCategoriaAtivaPorId(
    List<CategoriaPersonalizada> categoriasAtivas,
    String id,
  ) {
    return categoriasAtivas.where((c) => c.id == id).firstOrNull;
  }

  static bool nomeCategoriaDuplicado({
    required String nome,
    required List<CategoriaPersonalizada> categoriasAtivas,
    String? ignorarId,
  }) {
    final normalizado = TextNormalizer.normalizeForSearch(
      nome,
    ).trim().toLowerCase();
    if (normalizado.isEmpty) return false;

    final padraoDuplicado = CategoriaGasto.values.any(
      (item) =>
          TextNormalizer.normalizeForSearch(item.label).toLowerCase() ==
          normalizado,
    );

    if (padraoDuplicado) return true;

    return categoriasAtivas.any(
      (item) =>
          item.id != ignorarId &&
          TextNormalizer.normalizeForSearch(item.nome).toLowerCase() ==
              normalizado,
    );
  }
}
