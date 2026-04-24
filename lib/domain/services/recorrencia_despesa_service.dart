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

    var intervalosMensais = 0;
    final totalIntervalos = ordenados.length - 1;

    for (var i = 1; i < ordenados.length; i++) {
      final dias = ordenados[i].data
          .difference(ordenados[i - 1].data)
          .inDays
          .abs();
      if (dias >= 26 && dias <= 35) {
        intervalosMensais++;
      }
    }

    if (totalIntervalos == 0 || intervalosMensais < 2) {
      return null;
    }

    double somaDias = 0;
    double somaValores = 0;

    for (final g in ordenados) {
      somaDias += g.data.day;
      somaValores += g.valor.abs();
    }

    final mediaDia = somaDias / ordenados.length;
    final valorMedio = somaValores / ordenados.length;

    double somaDesvio = 0;
    for (final g in ordenados) {
      somaDesvio += (g.data.day - mediaDia).abs();
    }
    final desvioMedioDia = somaDesvio / ordenados.length;

    final scoreIntervalo = intervalosMensais / totalIntervalos;
    final scoreDia = (1 - (desvioMedioDia / 6)).clamp(0, 1).toDouble();
    final confianca = (scoreIntervalo * 0.8) + (scoreDia * 0.2);

    if (confianca < 0.65) {
      return null;
    }

    return SugestaoRecorrenciaDespesa(
      periodicidade: 'mensal',
      ocorrencias: ordenados.length,
      diaPreferencial: mediaDia.round().clamp(1, 28),
      valorMedio: valorMedio,
      confianca: confianca,
    );
  }
}
