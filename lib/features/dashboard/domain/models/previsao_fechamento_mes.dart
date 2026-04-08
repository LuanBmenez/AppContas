import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

class PrevisaoCategoriaRisco {
  const PrevisaoCategoriaRisco({
    required this.categoria,
    required this.gastoAtual,
    required this.projecaoFimMes,
    required this.orcamentoLimite,
  });

  final CategoriaGasto categoria;
  final double gastoAtual;
  final double projecaoFimMes;
  final double orcamentoLimite;

  double get percentualPrevistoOrcamento {
    if (orcamentoLimite <= 0) {
      return 0;
    }
    return (projecaoFimMes / orcamentoLimite) * 100;
  }
}

class PrevisaoFechamentoMes {
  const PrevisaoFechamentoMes({
    required this.gastoAtual,
    required this.mediaDiaria,
    required this.projecaoTotal,
    required this.recorrenciasRestantes,
    required this.categoriasComRisco,
    required this.diasPassados,
    required this.diasNoMes,
  });

  final double gastoAtual;
  final double mediaDiaria;
  final double projecaoTotal;
  final double recorrenciasRestantes;
  final List<PrevisaoCategoriaRisco> categoriasComRisco;
  final int diasPassados;
  final int diasNoMes;
}
