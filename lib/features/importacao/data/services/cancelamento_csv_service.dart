import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/extrato_csv_service.dart';

class TransacaoCanceladaDetectada {
  const TransacaoCanceladaDetectada({
    required this.gasto,
    required this.recebimento,
    required this.scoreMatch,
  });

  final Gasto gasto;
  final RecebimentoDetectado recebimento;
  final double scoreMatch;

  String get id {
    final gastoKey =
        gasto.hashImportacao ??
        '${gasto.titulo}|${gasto.data.toIso8601String()}|${gasto.valor.toStringAsFixed(2)}';
    return '$gastoKey|${recebimento.id}';
  }
}

class CancelamentoCsvService {
  /// Detecta pares de gasto e recebimento que se anulam (cancelamento/reembolso).
  /// Regras:
  /// - valor igual ou diferença <= 1 real
  /// - data diferença <= 2 dias
  /// - descrição normalizada semelhante (>= 0.7 de similaridade)
  List<TransacaoCanceladaDetectada> detectarCancelamentos({
    required List<Gasto> gastos,
    required List<RecebimentoDetectado> recebimentos,
  }) {
    final cancelados = <TransacaoCanceladaDetectada>[];
    final gastosUsados = <String>{};

    for (final receb in recebimentos) {
      Gasto? melhorGasto;
      double melhorScore = 0;

      for (final gasto in gastos) {
        final gastoKey =
            gasto.hashImportacao ??
            '${gasto.titulo}|${gasto.data.toIso8601String()}|${gasto.valor.toStringAsFixed(2)}';

        if (gastosUsados.contains(gastoKey)) continue;

        final diffValor = (gasto.valor.abs() - receb.valor.abs()).abs();
        if (diffValor > 1.0) continue;

        final diffDias = gasto.data.difference(receb.data).inDays.abs();
        if (diffDias > 2) continue;

        final scoreDesc = _similaridadeDescricao(
          gasto.titulo,
          receb.descricaoOriginal,
        );

        if (scoreDesc < 0.7) continue;

        final score =
            0.5 * (1 - (diffValor / (gasto.valor.abs() + 1))) +
            0.2 * (1 - diffDias / 3) +
            0.3 * scoreDesc;

        if (score > melhorScore) {
          melhorScore = score;
          melhorGasto = gasto;
        }
      }

      if (melhorGasto != null) {
        final transacao = TransacaoCanceladaDetectada(
          gasto: melhorGasto,
          recebimento: receb,
          scoreMatch: melhorScore,
        );

        cancelados.add(transacao);
        gastosUsados.add(
          melhorGasto.hashImportacao ??
              '${melhorGasto.titulo}|${melhorGasto.data.toIso8601String()}|${melhorGasto.valor.toStringAsFixed(2)}',
        );
      }
    }

    return cancelados;
  }

  double _similaridadeDescricao(String a, String b) {
    final na = _normalizar(a);
    final nb = _normalizar(b);
    if (na.isEmpty || nb.isEmpty) return 0;

    final sa = na.split(' ').toSet();
    final sb = nb.split(' ').toSet();
    final inter = sa.intersection(sb).length;
    final uniao = sa.union(sb).length;

    return uniao == 0 ? 0 : inter / uniao;
  }

  String _normalizar(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll(RegExp('[ç]'), 'c')
        .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
