import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/dashboard_summary_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/domain/models/previsao_fechamento_mes.dart';
import 'package:paga_o_que_me_deve/features/insights/domain/models/insight_item.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/domain/models/orcamento_categoria.dart';

class InsightsService {
  const InsightsService();

  List<InsightItem> gerarInsights({
    required DashboardResumoCalculado resumo,
    required PrevisaoFechamentoMes previsao,
    required List<OrcamentoCategoriaResumo> orcamentos,
    DateTime? agora,
    int limite = 5,
  }) {
    final referencia = agora ?? DateTime.now();
    final itens = <InsightItem>[];

    final orcamentosOrdenados = List<OrcamentoCategoriaResumo>.from(orcamentos)
      ..sort(
        (a, b) => b.percentualUtilizado.compareTo(a.percentualUtilizado),
      );

    for (final item in orcamentosOrdenados) {
      final percentual = item.percentualUtilizado * 100;
      final categoria = item.orcamento.categoriaPadrao.label;

      if (percentual >= 100) {
        itens.add(
          InsightItem(
            nivel: InsightNivel.alerta,
            // Texto de impacto solicitado:
            mensagem: 'Atenção: Orçamento de $categoria estourado este mês!',
            icone: Icons.error_outline_rounded,
          ),
        );
      } else if (percentual >= 80) {
        itens.add(
          InsightItem(
            nivel: InsightNivel.atencao,
            mensagem:
                'Cuidado! Você já consumiu ${percentual.toStringAsFixed(0)}% do orçamento de $categoria.',
            icone: Icons.warning_amber_rounded,
          ),
        );
      }
    }

    if (_ritmoAltoInicioMes(previsao, referencia)) {
      itens.add(
        const InsightItem(
          nivel: InsightNivel.atencao,
          mensagem: 'Seus gastos estão altos neste início de mês.',
          icone: Icons.speed_rounded,
        ),
      );
    }

    final orcamentoTotal = orcamentos.fold<double>(
      0,
      (total, item) => total + item.orcamento.valorLimite,
    );

    if (orcamentoTotal > 0 && previsao.projecaoTotal > orcamentoTotal) {
      itens.add(
        const InsightItem(
          nivel: InsightNivel.alerta,
          mensagem: 'Você deve ultrapassar seu orçamento este mês.',
          icone: Icons.trending_up_rounded,
        ),
      );
    }

    if (previsao.recorrenciasRestantes > 0) {
      itens.add(
        InsightItem(
          nivel: InsightNivel.info,
          mensagem:
              'Ainda faltam R\$ ${previsao.recorrenciasRestantes.toStringAsFixed(2)} em despesas recorrentes este mês.',
          icone: Icons.repeat_rounded,
        ),
      );
    }

    if (resumo.variacaoGastos > 0.1) {
      itens.add(
        const InsightItem(
          nivel: InsightNivel.info,
          mensagem: 'Você está gastando mais que no mês passado.',
          icone: Icons.compare_arrows_rounded,
        ),
      );
    }

    final unicos = <InsightItem>[];
    final mensagens = <String>{};
    for (final item in itens) {
      if (mensagens.add(item.mensagem)) {
        unicos.add(item);
      }
    }

    return unicos.take(limite).toList();
  }

  bool _ritmoAltoInicioMes(PrevisaoFechamentoMes previsao, DateTime agora) {
    if (previsao.gastoAtual <= 0) {
      return false;
    }
    if (agora.day > 10) {
      return false;
    }

    final razao = previsao.projecaoTotal <= 0
        ? 0
        : previsao.projecaoTotal / previsao.gastoAtual;

    return razao >= 1.7;
  }
}
