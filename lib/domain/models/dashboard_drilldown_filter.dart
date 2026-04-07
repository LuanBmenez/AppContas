import 'gasto.dart';

class DashboardDrillDownFilter {
  final DateTime? mesReferencia;
  final CategoriaGasto? categoriaPadrao;
  final String? categoriaPersonalizadaId;
  final TipoGasto? tipo;

  const DashboardDrillDownFilter({
    this.mesReferencia,
    this.categoriaPadrao,
    this.categoriaPersonalizadaId,
    this.tipo,
  });
}

