import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/dashboard_summary_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/domain/models/previsao_fechamento_mes.dart';
import 'package:paga_o_que_me_deve/features/insights/data/services/insights_service.dart';
import 'package:paga_o_que_me_deve/features/insights/domain/models/insight_item.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/domain/models/orcamento_categoria.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

void main() {
  group('InsightsService', () {
    const InsightsService service = InsightsService();

    DashboardResumoCalculado resumo({double variacaoGastos = 0}) {
      return DashboardResumoCalculado(
        totalGastosPeriodo: 1000,
        totalPendente: 0,
        saldo: -100,
        saldoPositivo: false,
        variacaoSaldo: 0,
        variacaoGastos: variacaoGastos,
        comparativoLabel: 'mês anterior',
        categoriasOrdenadas: const <DashboardCategoriaResumo>[],
        categoriaMaisGasta: null,
        categoriaMenosGasta: null,
      );
    }

    PrevisaoFechamentoMes previsao({
      double projecaoTotal = 1000,
      double recorrenciasRestantes = 0,
      double gastoAtual = 500,
    }) {
      return PrevisaoFechamentoMes(
        gastoAtual: gastoAtual,
        mediaDiaria: 50,
        projecaoTotal: projecaoTotal,
        recorrenciasRestantes: recorrenciasRestantes,
        categoriasComRisco: const <PrevisaoCategoriaRisco>[],
        diasPassados: 5,
        diasNoMes: 30,
      );
    }

    List<OrcamentoCategoriaResumo> orcamentos() {
      return <OrcamentoCategoriaResumo>[
        OrcamentoCategoriaResumo(
          orcamento: const OrcamentoCategoria(
            id: '1',
            categoriaPadrao: CategoriaGasto.comida,
            valorLimite: 1000,
          ),
          valorGasto: 820,
          valorRestante: 180,
          percentualUtilizado: 0.82,
          status: OrcamentoCategoriaStatus.alerta,
        ),
        OrcamentoCategoriaResumo(
          orcamento: const OrcamentoCategoria(
            id: '2',
            categoriaPadrao: CategoriaGasto.transporte,
            valorLimite: 500,
          ),
          valorGasto: 550,
          valorRestante: -50,
          percentualUtilizado: 1.1,
          status: OrcamentoCategoriaStatus.estourado,
        ),
      ];
    }

    test('gera insights de orcamento, recorrencia e comparacao', () {
      final List<InsightItem> insights = service.gerarInsights(
        resumo: resumo(variacaoGastos: 12),
        previsao: previsao(recorrenciasRestantes: 120, projecaoTotal: 1900),
        orcamentos: orcamentos(),
        agora: DateTime(2026, 4, 5),
      );

      expect(insights.isNotEmpty, isTrue);
      expect(
        insights.any((i) => i.mensagem.contains('ultrapassou o orçamento')),
        isTrue,
      );
      expect(
        insights.any((i) => i.mensagem.contains('já consumiu')),
        isTrue,
      );
      expect(
        insights.any((i) => i.mensagem.contains('despesas recorrentes')),
        isTrue,
      );
      expect(
        insights.any((i) => i.mensagem.contains('mês passado')),
        isTrue,
      );
    });

    test('limita quantidade maxima de insights', () {
      final List<InsightItem> insights = service.gerarInsights(
        resumo: resumo(variacaoGastos: 30),
        previsao: previsao(recorrenciasRestantes: 200, projecaoTotal: 3000),
        orcamentos: orcamentos(),
        agora: DateTime(2026, 4, 4),
        limite: 3,
      );

      expect(insights.length, 3);
    });
  });
}
