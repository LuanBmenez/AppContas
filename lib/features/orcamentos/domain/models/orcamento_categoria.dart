import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

class OrcamentoCategoria {
  const OrcamentoCategoria({
    required this.id,
    required this.categoriaPadrao,
    required this.valorLimite,
  });

  factory OrcamentoCategoria.fromMap(Map<String, dynamic> map, String id) {
    final categoriaRaw = (map['categoriaPadrao'] ?? 'outros').toString();
    final categoria = CategoriaGasto.values.firstWhere(
      (item) => item.name == categoriaRaw,
      orElse: () => CategoriaGasto.outros,
    );

    final dynamic limiteRaw = map['valorLimite'];
    final limite = limiteRaw is num
        ? limiteRaw.toDouble()
        : double.tryParse(limiteRaw?.toString() ?? '') ?? 0;

    return OrcamentoCategoria(
      id: id,
      categoriaPadrao: categoria,
      valorLimite: limite,
    );
  }

  final String id;
  final CategoriaGasto categoriaPadrao;
  final double valorLimite;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'categoriaPadrao': categoriaPadrao.name,
      'valorLimite': valorLimite,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
  }

  OrcamentoCategoria copyWith({
    String? id,
    CategoriaGasto? categoriaPadrao,
    double? valorLimite,
  }) {
    return OrcamentoCategoria(
      id: id ?? this.id,
      categoriaPadrao: categoriaPadrao ?? this.categoriaPadrao,
      valorLimite: valorLimite ?? this.valorLimite,
    );
  }
}

enum OrcamentoCategoriaStatus { normal, alerta, estourado }

class OrcamentoCategoriaResumo {
  const OrcamentoCategoriaResumo({
    required this.orcamento,
    required this.valorGasto,
    required this.valorRestante,
    required this.percentualUtilizado,
    required this.status,
  });

  final OrcamentoCategoria orcamento;
  final double valorGasto;
  final double valorRestante;
  final double percentualUtilizado;
  final OrcamentoCategoriaStatus status;
}
