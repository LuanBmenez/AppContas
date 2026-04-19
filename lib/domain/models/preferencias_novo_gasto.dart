import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

class PreferenciasNovoGasto {
  const PreferenciasNovoGasto({
    this.ultimaCategoriaPadrao,
    this.ultimaCategoriaPersonalizadaId,
    this.ultimoTipo,
    this.recentesPadrao = const <CategoriaGasto>[],
    this.recentesPersonalizadas = const <String>[],
  });
  final CategoriaGasto? ultimaCategoriaPadrao;
  final String? ultimaCategoriaPersonalizadaId;
  final TipoGasto? ultimoTipo;
  final List<CategoriaGasto> recentesPadrao;
  final List<String> recentesPersonalizadas;
}
