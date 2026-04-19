import 'package:paga_o_que_me_deve/domain/models/dashboard_drilldown_filter.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

class AppRoutes {
  AppRoutes._();

  static const String inicioPath = '/inicio';
  static const String gastosPath = '/despesas';
  static const String receberPath = '/receber';
  static const String guardadoPath = '/guardado';
  static const String perfilPath = '/perfil';
  static const String novoGastoPath = '/despesas/novo';
  static const String orcamentosPath = '/despesas/orcamentos';
  static const String cartoesPath = '/despesas/cartoes';
  static const String importarPath = '/despesas/importar';
  static const String recorrenciasPath = '/perfil/recorrencias';
  static const String novoRecebivelPath = '/receber/nova';

  @Deprecated('Use gastosPath')
  static const String despesasPath = gastosPath;
  @Deprecated('Use novoGastoPath')
  static const String novaDespesaPath = novoGastoPath;

  static const String inicioName = 'inicio';
  static const String gastosName = 'gastos';
  static const String receberName = 'receber';
  static const String guardadoName = 'guardado';
  static const String perfilName = 'perfil';
  static const String novoGastoName = 'gastos-novo';
  static const String orcamentosName = 'gastos-orcamentos';
  static const String cartoesName = 'despesas-cartoes';
  static const String importarName = 'despesas-importar';
  static const String recorrenciasName = 'perfil-recorrencias';
  static const String novoRecebivelName = 'receber-nova';

  @Deprecated('Use gastosName')
  static const String despesasName = gastosName;
  @Deprecated('Use novoGastoName')
  static const String novaDespesaName = novoGastoName;

  static Map<String, String> gastosQueryFromFilter(
    DashboardDrillDownFilter filter,
  ) {
    final query = <String, String>{};

    if (filter.mesReferencia != null) {
      final ano = filter.mesReferencia!.year.toString();
      final mes = filter.mesReferencia!.month.toString().padLeft(2, '0');
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

  static DashboardDrillDownFilter? gastosFilterFromQuery(
    Map<String, String> query,
  ) {
    final mesReferencia = _parseMes(query['mes']);
    final categoriaPadrao = _parseCategoria(query['categoria']);
    final categoriaCustomId = _parseNonEmpty(
      query['categoriaCustomId'],
    );
    final tipo = _parseTipo(query['tipo']);

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

  @Deprecated('Use gastosQueryFromFilter')
  static Map<String, String> despesasQueryFromFilter(
    DashboardDrillDownFilter filter,
  ) {
    return gastosQueryFromFilter(filter);
  }

  @Deprecated('Use gastosFilterFromQuery')
  static DashboardDrillDownFilter? despesasFilterFromQuery(
    Map<String, String> query,
  ) {
    return gastosFilterFromQuery(query);
  }

  static DateTime? _parseMes(String? value) {
    if (value == null || value.length != 7) {
      return null;
    }
    final partes = value.split('-');
    if (partes.length != 2) {
      return null;
    }
    final ano = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    if (ano == null || mes == null || mes < 1 || mes > 12) {
      return null;
    }
    return DateTime(ano, mes);
  }

  static CategoriaGasto? _parseCategoria(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final categoria in CategoriaGasto.values) {
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
    for (final tipo in TipoGasto.values) {
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
