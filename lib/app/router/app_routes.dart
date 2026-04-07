import '../../domain/models/dashboard_drilldown_filter.dart';
import '../../domain/models/gasto.dart';

class AppRoutes {
  AppRoutes._();

  static const String inicioPath = '/inicio';
  static const String despesasPath = '/despesas';
  static const String receberPath = '/receber';
  static const String novaDespesaPath = '/despesas/novo';
  static const String cartoesPath = '/despesas/cartoes';
  static const String importarPath = '/despesas/importar';
  static const String novoRecebivelPath = '/receber/nova';

  static const String inicioName = 'inicio';
  static const String despesasName = 'despesas';
  static const String receberName = 'receber';
  static const String novaDespesaName = 'despesas-novo';
  static const String cartoesName = 'despesas-cartoes';
  static const String importarName = 'despesas-importar';
  static const String novoRecebivelName = 'receber-nova';

  static Map<String, String> despesasQueryFromFilter(
    DashboardDrillDownFilter filter,
  ) {
    final Map<String, String> query = <String, String>{};

    if (filter.mesReferencia != null) {
      final String ano = filter.mesReferencia!.year.toString();
      final String mes = filter.mesReferencia!.month.toString().padLeft(2, '0');
      query['mes'] = '$ano-$mes';
    }

    if (filter.categoriaPadrao != null) {
      query['categoria'] = filter.categoriaPadrao!.name;
    }

    if ((filter.categoriaPersonalizadaId ?? '').isNotEmpty) {
      query['categoriaCustomId'] = filter.categoriaPersonalizadaId!;
    }

    if (filter.tipo != null) {
      query['tipo'] = filter.tipo!.name;
    }

    return query;
  }

  static DashboardDrillDownFilter? despesasFilterFromQuery(
    Map<String, String> query,
  ) {
    final DateTime? mesReferencia = _parseMes(query['mes']);
    final CategoriaGasto? categoriaPadrao = _parseCategoria(query['categoria']);
    final String? categoriaCustomId = _parseNonEmpty(
      query['categoriaCustomId'],
    );
    final TipoGasto? tipo = _parseTipo(query['tipo']);

    if (mesReferencia == null &&
        categoriaPadrao == null &&
        categoriaCustomId == null &&
        tipo == null) {
      return null;
    }

    return DashboardDrillDownFilter(
      mesReferencia: mesReferencia,
      categoriaPadrao: categoriaPadrao,
      categoriaPersonalizadaId: categoriaCustomId,
      tipo: tipo,
    );
  }

  static DateTime? _parseMes(String? value) {
    if (value == null || value.length != 7) {
      return null;
    }
    final List<String> partes = value.split('-');
    if (partes.length != 2) {
      return null;
    }
    final int? ano = int.tryParse(partes[0]);
    final int? mes = int.tryParse(partes[1]);
    if (ano == null || mes == null || mes < 1 || mes > 12) {
      return null;
    }
    return DateTime(ano, mes, 1);
  }

  static CategoriaGasto? _parseCategoria(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final CategoriaGasto categoria in CategoriaGasto.values) {
      if (categoria.name == value) {
        return categoria;
      }
    }
    return null;
  }

  static TipoGasto? _parseTipo(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final TipoGasto tipo in TipoGasto.values) {
      if (tipo.name == value) {
        return tipo;
      }
    }
    return null;
  }

  static String? _parseNonEmpty(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
