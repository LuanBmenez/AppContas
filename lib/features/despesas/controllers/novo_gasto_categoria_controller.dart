import '../../../domain/models/categoria_personalizada.dart';
import '../../../domain/models/gasto.dart';
import '../../../core/utils/text_normalizer.dart';

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
  }) {
    final String normalizado = TextNormalizer.normalizeForSearch(
      titulo,
    ).toLowerCase();

    if (normalizado.isEmpty) {
      return const CategoriaSugestaoResultado(
        categoriaPadrao: null,
        categoriaPersonalizadaId: null,
      );
    }

    String? customId;
    for (final CategoriaPersonalizada categoria in categoriasAtivas) {
      final String nome = TextNormalizer.normalizeForSearch(
        categoria.nome,
      ).toLowerCase();
      if (nome.isNotEmpty && normalizado.contains(nome)) {
        customId = categoria.id;
        break;
      }
    }

    if (customId != null) {
      return CategoriaSugestaoResultado(
        categoriaPadrao: null,
        categoriaPersonalizadaId: customId,
      );
    }

    CategoriaGasto? sugerida;
    for (final MapEntry<String, CategoriaGasto> entry
        in _sugestoesPadrao.entries) {
      if (normalizado.contains(entry.key)) {
        sugerida = entry.value;
        break;
      }
    }

    return CategoriaSugestaoResultado(
      categoriaPadrao: sugerida,
      categoriaPersonalizadaId: null,
    );
  }

  static List<CategoriaGasto> filtrarCategoriasPadrao(String textoBusca) {
    final String busca = TextNormalizer.normalizeForSearch(
      textoBusca,
    ).toLowerCase();
    if (busca.isEmpty) {
      return CategoriaGasto.values;
    }

    return CategoriaGasto.values.where((categoria) {
      final String nome = TextNormalizer.normalizeForSearch(
        categoria.label,
      ).toLowerCase();
      return nome.contains(busca);
    }).toList();
  }

  static List<CategoriaPersonalizada> filtrarCategoriasPersonalizadas(
    String textoBusca,
    List<CategoriaPersonalizada> categoriasAtivas,
  ) {
    final String busca = TextNormalizer.normalizeForSearch(
      textoBusca,
    ).toLowerCase();
    final List<CategoriaPersonalizada> base = <CategoriaPersonalizada>[
      ...categoriasAtivas,
    ];

    if (busca.isEmpty) {
      base.sort((a, b) {
        if (a.favorita != b.favorita) {
          return a.favorita ? -1 : 1;
        }
        return b.usoCount.compareTo(a.usoCount);
      });
      return base;
    }

    return base.where((categoria) {
      final String nome = TextNormalizer.normalizeForSearch(
        categoria.nome,
      ).toLowerCase();
      return nome.contains(busca);
    }).toList();
  }

  static CategoriaPersonalizada? buscarCategoriaAtivaPorId(
    List<CategoriaPersonalizada> categoriasAtivas,
    String id,
  ) {
    for (final CategoriaPersonalizada categoria in categoriasAtivas) {
      if (categoria.id == id) {
        return categoria;
      }
    }
    return null;
  }

  static bool nomeCategoriaDuplicado({
    required String nome,
    required List<CategoriaPersonalizada> categoriasAtivas,
    String? ignorarId,
  }) {
    final String normalizado = TextNormalizer.normalizeForSearch(
      nome,
    ).trim().toLowerCase();

    if (normalizado.isEmpty) {
      return false;
    }

    for (final CategoriaGasto item in CategoriaGasto.values) {
      final String padrao = TextNormalizer.normalizeForSearch(
        item.label,
      ).toLowerCase();
      if (padrao == normalizado) {
        return true;
      }
    }

    for (final CategoriaPersonalizada item in categoriasAtivas) {
      if (item.id == ignorarId) {
        continue;
      }
      final String existente = TextNormalizer.normalizeForSearch(
        item.nome,
      ).toLowerCase();
      if (existente == normalizado) {
        return true;
      }
    }

    return false;
  }
}
