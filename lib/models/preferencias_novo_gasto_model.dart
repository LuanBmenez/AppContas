import 'gasto_model.dart';

class PreferenciasNovoGasto {
  final CategoriaGasto? ultimaCategoriaPadrao;
  final String? ultimaCategoriaPersonalizadaId;
  final TipoGasto? ultimoTipo;
  final List<CategoriaGasto> recentesPadrao;
  final List<String> recentesPersonalizadas;

  const PreferenciasNovoGasto({
    this.ultimaCategoriaPadrao,
    this.ultimaCategoriaPersonalizadaId,
    this.ultimoTipo,
    this.recentesPadrao = const <CategoriaGasto>[],
    this.recentesPersonalizadas = const <String>[],
  });
}
