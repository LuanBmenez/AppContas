import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class RecorrenciaDespesaService {
  const RecorrenciaDespesaService();

  SugestaoRecorrenciaDespesa? detectarMensal(List<Gasto> gastos) {
    if (gastos.length < 3) {
      return null;
    }

    final ordenados = List<Gasto>.from(gastos)
      ..sort((a, b) => a.data.compareTo(b.data));

    final intervalosDias = <int>[];
    for (var i = 1; i < ordenados.length; i++) {
      final dias = ordenados[i].data
          .difference(ordenados[i - 1].data)
          .inDays
          .abs();
      intervalosDias.add(dias);
    }

    final intervalosMensais = intervalosDias
        .where((dias) => dias >= 26 && dias <= 35)
        .length;
    final totalIntervalos = intervalosDias.length;
    if (totalIntervalos == 0 || intervalosMensais < 2) {
      return null;
    }

    final diasMes = ordenados.map((g) => g.data.day).toList();
    final mediaDia = diasMes.reduce((a, b) => a + b) / diasMes.length;
    final desvioMedioDia =
        diasMes.map((dia) => (dia - mediaDia).abs()).reduce((a, b) => a + b) /
        diasMes.length;

    final scoreIntervalo = intervalosMensais / totalIntervalos;
    final scoreDia = (1 - (desvioMedioDia / 6)).clamp(0, 1).toDouble();
    final confianca = (scoreIntervalo * 0.8) + (scoreDia * 0.2);

    if (confianca < 0.65) {
      return null;
    }

    final valorMedio =
        ordenados.map((g) => g.valor.abs()).reduce((a, b) => a + b) /
        ordenados.length;

    return SugestaoRecorrenciaDespesa(
      periodicidade: 'mensal',
      ocorrencias: ordenados.length,
      diaPreferencial: mediaDia.round().clamp(1, 28),
      valorMedio: valorMedio,
      confianca: confianca,
    );
  }
}
