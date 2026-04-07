import '../domain/models/gasto.dart';
import '../domain/repositories/finance_repository.dart';

class RecorrenciaDespesaService {
  const RecorrenciaDespesaService();

  SugestaoRecorrenciaDespesa? detectarMensal(List<Gasto> gastos) {
    if (gastos.length < 3) {
      return null;
    }

    final List<Gasto> ordenados = List<Gasto>.from(gastos)
      ..sort((a, b) => a.data.compareTo(b.data));

    final List<int> intervalosDias = <int>[];
    for (int i = 1; i < ordenados.length; i++) {
      final int dias = ordenados[i].data
          .difference(ordenados[i - 1].data)
          .inDays
          .abs();
      intervalosDias.add(dias);
    }

    final int intervalosMensais = intervalosDias
        .where((dias) => dias >= 26 && dias <= 35)
        .length;
    final int totalIntervalos = intervalosDias.length;
    if (totalIntervalos == 0 || intervalosMensais < 2) {
      return null;
    }

    final List<int> diasMes = ordenados.map((g) => g.data.day).toList();
    final double mediaDia = diasMes.reduce((a, b) => a + b) / diasMes.length;
    final double desvioMedioDia =
        diasMes.map((dia) => (dia - mediaDia).abs()).reduce((a, b) => a + b) /
        diasMes.length;

    final double scoreIntervalo = intervalosMensais / totalIntervalos;
    final double scoreDia = (1 - (desvioMedioDia / 6)).clamp(0, 1).toDouble();
    final double confianca = (scoreIntervalo * 0.8) + (scoreDia * 0.2);

    if (confianca < 0.65) {
      return null;
    }

    final double valorMedio =
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
