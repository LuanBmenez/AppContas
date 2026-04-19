import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/domain/services/recorrencia_despesa_service.dart';
import 'package:paga_o_que_me_deve/features/dashboard/domain/models/previsao_fechamento_mes.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/domain/models/orcamento_categoria.dart';

class PrevisaoFechamentoService {
  const PrevisaoFechamentoService({
    RecorrenciaDespesaService recorrenciaDespesaService =
        const RecorrenciaDespesaService(),
  }) : _recorrenciaDespesaService = recorrenciaDespesaService;

  final RecorrenciaDespesaService _recorrenciaDespesaService;

  PrevisaoFechamentoMes calcular({
    required DashboardResumo resumo,
    required List<OrcamentoCategoriaResumo> orcamentosCategoria,
    DateTime? agora,
  }) {
    final referencia = agora ?? DateTime.now();
    final inicioMes = DateTime(referencia.year, referencia.month);
    final fimMesExclusivo = DateTime(
      referencia.year,
      referencia.month + 1,
    );
    final fimDiaAtual = DateTime(
      referencia.year,
      referencia.month,
      referencia.day,
      23,
      59,
      59,
      999,
    );

    final diasNoMes = DateTime(
      referencia.year,
      referencia.month + 1,
      0,
    ).day;
    final diasPassados = referencia.day.clamp(1, diasNoMes);

    final gastosMes = resumo.gastos.where((gasto) {
      return !gasto.data.isBefore(inicioMes) &&
          gasto.data.isBefore(fimMesExclusivo);
    }).toList();

    final gastosAteAgora = gastosMes.where((gasto) {
      return !gasto.data.isAfter(fimDiaAtual);
    }).toList();

    final gastoAtual = gastosAteAgora.fold<double>(
      0,
      (total, gasto) => total + gasto.valor,
    );

    final gastoVariavelAtual = gastosAteAgora
        .where((gasto) => gasto.tipo == TipoGasto.variavel)
        .fold<double>(0, (total, gasto) => total + gasto.valor);

    final mediaDiaria = diasPassados <= 0 ? 0.0 : gastoAtual / diasPassados;

    final recorrenciasRestantes = _calcularRecorrenciasRestantes(
      gastos: resumo.gastos,
      referencia: referencia,
      fimDiaAtual: fimDiaAtual,
      inicioMes: inicioMes,
      fimMesExclusivo: fimMesExclusivo,
    );

    final projecaoVariavel = _calcularProjecaoVariavelConservadora(
      gastoAtual: gastoAtual,
      gastoVariavelAtual: gastoVariavelAtual,
      diasPassados: diasPassados,
      diasNoMes: diasNoMes,
    );
    final projecaoTotal = _aplicarLimiteRazoavel(
      projecaoVariavel: projecaoVariavel,
      gastoAtual: gastoAtual,
      recorrenciasRestantes: recorrenciasRestantes,
      diasPassados: diasPassados,
    );

    final categoriasComRisco = _calcularCategoriasComRisco(
      gastosAteAgora: gastosAteAgora,
      orcamentosCategoria: orcamentosCategoria,
      diasPassados: diasPassados,
      diasNoMes: diasNoMes,
    );

    return PrevisaoFechamentoMes(
      gastoAtual: gastoAtual,
      mediaDiaria: mediaDiaria,
      projecaoTotal: projecaoTotal,
      recorrenciasRestantes: recorrenciasRestantes,
      categoriasComRisco: categoriasComRisco,
      diasPassados: diasPassados,
      diasNoMes: diasNoMes,
    );
  }

  double _calcularRecorrenciasRestantes({
    required List<Gasto> gastos,
    required DateTime referencia,
    required DateTime fimDiaAtual,
    required DateTime inicioMes,
    required DateTime fimMesExclusivo,
  }) {
    final recorrenciasFixasAgendadasNoMes = gastos
        .where(
          (gasto) =>
              gasto.tipo == TipoGasto.fixo &&
              gasto.data.isAfter(fimDiaAtual) &&
              !gasto.data.isBefore(inicioMes) &&
              gasto.data.isBefore(fimMesExclusivo),
        )
        .fold<double>(0, (total, gasto) => total + gasto.valor);

    final gruposPorTitulo = <String, List<Gasto>>{};

    for (final gasto in gastos) {
      final tituloNormalizado = TextNormalizer.normalizeForSearch(
        gasto.titulo,
      );
      if (tituloNormalizado.length < 3) {
        continue;
      }

      gruposPorTitulo
          .putIfAbsent(tituloNormalizado, () => <Gasto>[])
          .add(gasto);
    }

    var totalRestante = recorrenciasFixasAgendadasNoMes;
    for (final grupo in gruposPorTitulo.values) {
      final sugestao = _recorrenciaDespesaService.detectarMensal(grupo);
      if (sugestao == null) {
        continue;
      }

      final lancamentosMes = grupo.where((gasto) {
        return !gasto.data.isBefore(inicioMes) &&
            gasto.data.isBefore(fimMesExclusivo);
      }).toList();

      final futurosNoMesNaoFixos = lancamentosMes
          .where(
            (gasto) =>
                gasto.tipo != TipoGasto.fixo && gasto.data.isAfter(fimDiaAtual),
          )
          .fold<double>(0, (total, gasto) => total + gasto.valor);

      if (futurosNoMesNaoFixos > 0) {
        totalRestante += futurosNoMesNaoFixos;
        continue;
      }

      final jaOcorreuNoMes = lancamentosMes.any((gasto) {
        return !gasto.data.isAfter(fimDiaAtual);
      });

      if (!jaOcorreuNoMes && lancamentosMes.isEmpty) {
        if (referencia.day <= 28) {
          totalRestante += sugestao.valorMedio;
        }
      }
    }

    return totalRestante;
  }

  double _calcularProjecaoVariavelConservadora({
    required double gastoAtual,
    required double gastoVariavelAtual,
    required int diasPassados,
    required int diasNoMes,
  }) {
    if (gastoAtual <= 0 || diasPassados <= 0 || diasNoMes <= 0) {
      return 0;
    }

    final diasRestantes = (diasNoMes - diasPassados).clamp(0, diasNoMes);
    if (diasRestantes <= 0 || gastoVariavelAtual <= 0) {
      return gastoAtual;
    }

    final mediaVariavelDiaria = gastoVariavelAtual / diasPassados;
    final double fatorSuavizacao;
    if (diasPassados < 7) {
      fatorSuavizacao = 0.30;
    } else if (diasPassados < 15) {
      fatorSuavizacao = 0.45;
    } else {
      fatorSuavizacao = 0.65;
    }

    final adicionalProjetado =
        mediaVariavelDiaria * diasRestantes * fatorSuavizacao;
    final projetado = gastoAtual + adicionalProjetado;
    return projetado < gastoAtual ? gastoAtual : projetado;
  }

  double _aplicarLimiteRazoavel({
    required double projecaoVariavel,
    required double gastoAtual,
    required double recorrenciasRestantes,
    required int diasPassados,
  }) {
    final base =
        (projecaoVariavel < gastoAtual ? gastoAtual : projecaoVariavel) +
        recorrenciasRestantes;

    if (gastoAtual <= 0) {
      return base;
    }

    final double multiplicadorMaximo;
    if (diasPassados < 7) {
      multiplicadorMaximo = 1.8;
    } else if (diasPassados < 15) {
      multiplicadorMaximo = 2.2;
    } else {
      multiplicadorMaximo = 3.0;
    }

    final limite = (gastoAtual * multiplicadorMaximo) + recorrenciasRestantes;
    return base > limite ? limite : base;
  }

  List<PrevisaoCategoriaRisco> _calcularCategoriasComRisco({
    required List<Gasto> gastosAteAgora,
    required List<OrcamentoCategoriaResumo> orcamentosCategoria,
    required int diasPassados,
    required int diasNoMes,
  }) {
    final gastoAtualPorCategoria = <CategoriaGasto, double>{};

    for (final gasto in gastosAteAgora) {
      if (gasto.usaCategoriaPersonalizada) {
        continue;
      }
      gastoAtualPorCategoria[gasto.categoria] =
          (gastoAtualPorCategoria[gasto.categoria] ?? 0) + gasto.valor;
    }

    final riscos = <PrevisaoCategoriaRisco>[];
    for (final resumoOrcamento in orcamentosCategoria) {
      final categoria = resumoOrcamento.orcamento.categoriaPadrao;
      final limite = resumoOrcamento.orcamento.valorLimite;
      final gastoAtual = gastoAtualPorCategoria[categoria] ?? 0;

      final projecao = diasPassados <= 0
          ? 0.0
          : (gastoAtual / diasPassados) * diasNoMes;

      if (limite > 0 && projecao > limite) {
        riscos.add(
          PrevisaoCategoriaRisco(
            categoria: categoria,
            gastoAtual: gastoAtual,
            projecaoFimMes: projecao,
            orcamentoLimite: limite,
          ),
        );
      }
    }

    riscos.sort((a, b) {
      return b.percentualPrevistoOrcamento.compareTo(
        a.percentualPrevistoOrcamento,
      );
    });

    return riscos;
  }
}
