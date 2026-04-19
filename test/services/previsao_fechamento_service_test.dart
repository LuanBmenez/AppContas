import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/previsao_fechamento_service.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/domain/models/orcamento_categoria.dart';

void main() {
  group('PrevisaoFechamentoService', () {
    const service = PrevisaoFechamentoService();

    test('calcula projecao total com base no ritmo diario do mes', () {
      final resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Mercado',
          valor: 300,
          data: DateTime(2026, 4, 2),
          categoria: CategoriaGasto.comida,
        ),
        Gasto(
          id: 'g2',
          titulo: 'Uber',
          valor: 200,
          data: DateTime(2026, 4, 8),
          categoria: CategoriaGasto.transporte,
        ),
      ], const <Conta>[]);

      final previsao = service.calcular(
        resumo: resumo,
        orcamentosCategoria: const <OrcamentoCategoriaResumo>[],
        agora: DateTime(2026, 4, 10),
      );

      expect(previsao.gastoAtual, 500);
      expect(previsao.mediaDiaria, 50);
      expect(previsao.projecaoTotal, closeTo(950, 0.001));
      expect(previsao.diasPassados, 10);
      expect(previsao.diasNoMes, 30);
    });

    test('evita explosao no inicio do mes com poucos dados', () {
      final resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Compra alta',
          valor: 1200,
          data: DateTime(2026, 4, 2),
          categoria: CategoriaGasto.outros,
        ),
      ], const <Conta>[]);

      final previsao = service.calcular(
        resumo: resumo,
        orcamentosCategoria: const <OrcamentoCategoriaResumo>[],
        agora: DateTime(2026, 4, 3),
      );

      // Sem protecao seria 12000 (1200/3*30); no MVP fica amortecido.
      expect(previsao.projecaoTotal, lessThan(5000));
      expect(previsao.projecaoTotal, greaterThanOrEqualTo(previsao.gastoAtual));
    });

    test('nao duplica recorrencia ja lancada no mes atual', () {
      final resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Netflix assinatura',
          valor: 39.9,
          data: DateTime(2026, 1, 10),
          categoria: CategoriaGasto.entretenimento,
          tipo: TipoGasto.fixo,
        ),
        Gasto(
          id: 'g2',
          titulo: 'Netflix assinatura',
          valor: 39.9,
          data: DateTime(2026, 2, 10),
          categoria: CategoriaGasto.entretenimento,
          tipo: TipoGasto.fixo,
        ),
        Gasto(
          id: 'g3',
          titulo: 'Netflix assinatura',
          valor: 39.9,
          data: DateTime(2026, 3, 10),
          categoria: CategoriaGasto.entretenimento,
          tipo: TipoGasto.fixo,
        ),
        Gasto(
          id: 'g4',
          titulo: 'Netflix assinatura',
          valor: 39.9,
          data: DateTime(2026, 4, 10),
          categoria: CategoriaGasto.entretenimento,
          tipo: TipoGasto.fixo,
        ),
      ], const <Conta>[]);

      final previsao = service.calcular(
        resumo: resumo,
        orcamentosCategoria: const <OrcamentoCategoriaResumo>[],
        agora: DateTime(2026, 4, 12),
      );

      expect(previsao.recorrenciasRestantes, 0);
    });

    test('estima recorrencia restante quando nao ha lancamento no mes', () {
      final resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Academia',
          valor: 100,
          data: DateTime(2026, 1, 5),
          categoria: CategoriaGasto.saude,
          tipo: TipoGasto.fixo,
        ),
        Gasto(
          id: 'g2',
          titulo: 'Academia',
          valor: 100,
          data: DateTime(2026, 2, 5),
          categoria: CategoriaGasto.saude,
          tipo: TipoGasto.fixo,
        ),
        Gasto(
          id: 'g3',
          titulo: 'Academia',
          valor: 100,
          data: DateTime(2026, 3, 5),
          categoria: CategoriaGasto.saude,
          tipo: TipoGasto.fixo,
        ),
      ], const <Conta>[]);

      final previsao = service.calcular(
        resumo: resumo,
        orcamentosCategoria: const <OrcamentoCategoriaResumo>[],
        agora: DateTime(2026, 4, 12),
      );

      expect(previsao.recorrenciasRestantes, 100);
    });

    test(
      'considera lancamentos fixos futuros do mes como recorrencias restantes',
      () {
        final resumo = DashboardResumo(<Gasto>[
          Gasto(
            id: 'g1',
            titulo: 'Internet',
            valor: 120,
            data: DateTime(2026, 4, 25),
            categoria: CategoriaGasto.moradia,
            tipo: TipoGasto.fixo,
          ),
        ], const <Conta>[]);

        final previsao = service.calcular(
          resumo: resumo,
          orcamentosCategoria: const <OrcamentoCategoriaResumo>[],
          agora: DateTime(2026, 4, 10),
        );

        expect(previsao.recorrenciasRestantes, 120);
      },
    );

    test(
      'considera lancamentos futuros do mes mesmo sem tipo fixo quando padrao mensal existe',
      () {
        final resumo = DashboardResumo(<Gasto>[
          Gasto(
            id: 'g1',
            titulo: 'Plano celular',
            valor: 60,
            data: DateTime(2026, 1, 15),
            categoria: CategoriaGasto.outros,
          ),
          Gasto(
            id: 'g2',
            titulo: 'Plano celular',
            valor: 60,
            data: DateTime(2026, 2, 15),
            categoria: CategoriaGasto.outros,
          ),
          Gasto(
            id: 'g3',
            titulo: 'Plano celular',
            valor: 60,
            data: DateTime(2026, 3, 15),
            categoria: CategoriaGasto.outros,
          ),
          Gasto(
            id: 'g4',
            titulo: 'Plano celular',
            valor: 60,
            data: DateTime(2026, 4, 15),
            categoria: CategoriaGasto.outros,
          ),
        ], const <Conta>[]);

        final previsao = service.calcular(
          resumo: resumo,
          orcamentosCategoria: const <OrcamentoCategoriaResumo>[],
          agora: DateTime(2026, 4, 10),
        );

        expect(previsao.recorrenciasRestantes, 60);
      },
    );

    test('lista categorias com risco de estouro do orcamento', () {
      final resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Mercado',
          valor: 300,
          data: DateTime(2026, 4, 3),
          categoria: CategoriaGasto.comida,
        ),
        Gasto(
          id: 'g2',
          titulo: 'Mercado semanal',
          valor: 300,
          data: DateTime(2026, 4, 8),
          categoria: CategoriaGasto.comida,
        ),
        Gasto(
          id: 'g3',
          titulo: 'Cinema',
          valor: 40,
          data: DateTime(2026, 4, 5),
          categoria: CategoriaGasto.entretenimento,
        ),
      ], const <Conta>[]);

      final orcamentos =
          <OrcamentoCategoriaResumo>[
            const OrcamentoCategoriaResumo(
              orcamento: OrcamentoCategoria(
                id: 'o1',
                categoriaPadrao: CategoriaGasto.comida,
                valorLimite: 600,
              ),
              valorGasto: 0,
              valorRestante: 0,
              percentualUtilizado: 0,
              status: OrcamentoCategoriaStatus.normal,
            ),
            const OrcamentoCategoriaResumo(
              orcamento: OrcamentoCategoria(
                id: 'o2',
                categoriaPadrao: CategoriaGasto.entretenimento,
                valorLimite: 400,
              ),
              valorGasto: 0,
              valorRestante: 0,
              percentualUtilizado: 0,
              status: OrcamentoCategoriaStatus.normal,
            ),
          ];

      final previsao = service.calcular(
        resumo: resumo,
        orcamentosCategoria: orcamentos,
        agora: DateTime(2026, 4, 10),
      );

      expect(previsao.categoriasComRisco.length, 1);
      expect(
        previsao.categoriasComRisco.first.categoria,
        CategoriaGasto.comida,
      );
      expect(previsao.categoriasComRisco.first.projecaoFimMes, 1800);
    });
  });
}
