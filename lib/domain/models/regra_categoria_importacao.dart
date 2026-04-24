import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

class RegraCategoriaImportacao {
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
      // Otimizado com asNameMap()
      categoria:
          CategoriaGasto.values.asNameMap()[map['categoria']] ??
          CategoriaGasto.outros,
    );
  }

  final String id;
  final String termo;
  final CategoriaGasto categoria;

  Map<String, dynamic> toMap() {
    return {'termo': termo, 'categoria': categoria.name};
  }
}
