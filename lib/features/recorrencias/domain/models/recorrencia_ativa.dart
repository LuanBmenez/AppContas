import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

class RecorrenciaAtiva {
  const RecorrenciaAtiva({
    required this.id,
    required this.titulo,
    required this.valorMedio,
    required this.categoriaLabel,
    required this.diaDoMes,
    required this.ativosDesdeHoje,
  });

  final String id;
  final String titulo;
  final double valorMedio;
  final String categoriaLabel;
  final int diaDoMes;
  final List<Gasto> ativosDesdeHoje;
}
