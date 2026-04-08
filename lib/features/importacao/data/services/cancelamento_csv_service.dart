import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/extrato_csv_service.dart';

class TransacaoCanceladaDetectada {
  final Gasto gasto;
  final RecebimentoDetectado recebimento;
  final double scoreMatch;

  const TransacaoCanceladaDetectada({
    required this.gasto,
    required this.recebimento,
    required this.scoreMatch,
  });
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
    final List<TransacaoCanceladaDetectada> cancelados = [];
    final Set<String> gastosUsados = {};

    for (final receb in recebimentos) {
      Gasto? melhorGasto;
      double melhorScore = 0;

      for (final gasto in gastos) {
        if (gastosUsados.contains(gasto.id)) continue;

        final double diffValor = (gasto.valor.abs() - receb.valor.abs()).abs();
        if (diffValor > 1.0) continue;

        final int diffDias = (gasto.data.difference(receb.data).inDays).abs();
        if (diffDias > 2) continue;

        final double scoreDesc = _similaridadeDescricao(
          gasto.titulo,
          receb.descricaoOriginal,
        );

        if (scoreDesc < 0.7) continue;

        final double score =
            0.5 * (1 - (diffValor / (gasto.valor.abs() + 1))) +
            0.2 * (1 - diffDias / 3) +
            0.3 * scoreDesc;

        if (score > melhorScore) {
          melhorScore = score;
          melhorGasto = gasto;
        }
      }

      if (melhorGasto != null) {
        cancelados.add(
          TransacaoCanceladaDetectada(
            gasto: melhorGasto,
            recebimento: receb,
            scoreMatch: melhorScore,
          ),
        );
        gastosUsados.add(melhorGasto.id);
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
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
