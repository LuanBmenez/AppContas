import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

class DashboardDrillDownFilter {
  const DashboardDrillDownFilter({
    this.mesReferencia,
    this.categoriaPadrao,
    this.categoriaPersonalizadaId,
    this.tipo,
  });
  final DateTime? mesReferencia;
  final CategoriaGasto? categoriaPadrao;
  final String? categoriaPersonalizadaId;
  final TipoGasto? tipo;
}
