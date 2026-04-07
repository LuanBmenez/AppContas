import 'gasto.dart';

class RegraCategoriaImportacao {
  final String id;
  final String termo;
  final CategoriaGasto categoria;

  const RegraCategoriaImportacao({
    required this.id,
    required this.termo,
    required this.categoria,
  });

  factory RegraCategoriaImportacao.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return RegraCategoriaImportacao(
      id: id,
      termo: (map['termo'] ?? '').toString(),
      categoria: CategoriaGasto.values.firstWhere(
        (c) => c.name == map['categoria'],
        orElse: () => CategoriaGasto.outros,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {'termo': termo, 'categoria': categoria.name};
  }
}

