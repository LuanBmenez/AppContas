import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/dashboard/data/services/dashboard_summary_service.dart';

void main() {
  group('DashboardSummaryService', () {
    test('calcula saldo e categoria lider corretamente', () {
      final DashboardSummaryService service = DashboardSummaryService();
      final DateTime agora = DateTime(2026, 4, 15);

      final DashboardResumo resumo = DashboardResumo(
        <Gasto>[
          Gasto(
            id: 'g1',
            titulo: 'Mercado',
            valor: 200,
            data: DateTime(2026, 4, 10),
            categoria: CategoriaGasto.comida,
          ),
          Gasto(
            id: 'g2',
            titulo: 'Uber',
            valor: 50,
            data: DateTime(2026, 4, 11),
            categoria: CategoriaGasto.transporte,
          ),
        ],
        <Conta>[
          Conta(
            id: 'c1',
            nome: 'Cliente',
            descricao: 'Servico',
            valor: 500,
            data: DateTime(2026, 4, 8),
            foiPago: true,
          ),
        ],
      );

      final DashboardResumoCalculado calculado = service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.mes,
        agora: agora,
      );

      expect(calculado.totalGastosPeriodo, 250);
      expect(calculado.saldo, 250);
      expect(calculado.categoriaMaisGasta?.label, 'Comida');
    });

    test('reutiliza cache para mesma instancia e mesmo filtro', () {
      final DashboardSummaryService service = DashboardSummaryService();
      final DateTime agora = DateTime(2026, 4, 20);
      final DashboardResumo resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Internet',
          valor: 120,
          data: DateTime(2026, 4, 2),
          categoria: CategoriaGasto.moradia,
        ),
      ], const <Conta>[]);

      final DashboardResumoCalculado primeiro = service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.mes,
        agora: agora,
      );
      final DashboardResumoCalculado segundo = service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.mes,
        agora: agora,
      );

      expect(identical(primeiro, segundo), isTrue);
    });

    test('expira cache por TTL configurado', () {
      final DashboardSummaryService service = DashboardSummaryService(
        cacheTtl: const Duration(minutes: 1),
      );
      final DashboardResumo resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Academia',
          valor: 90,
          data: DateTime(2026, 4, 10),
          categoria: CategoriaGasto.saude,
        ),
      ], const <Conta>[]);

      final DashboardResumoCalculado primeiro = service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.mes,
        agora: DateTime(2026, 4, 15, 10, 0),
      );
      final DashboardResumoCalculado aposTtl = service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.mes,
        agora: DateTime(2026, 4, 15, 10, 2),
      );

      expect(identical(primeiro, aposTtl), isFalse);
    });

    test('aplica LRU quando excede limite de entradas', () {
      final DashboardSummaryService service = DashboardSummaryService(
        maxCacheEntries: 2,
        cacheTtl: const Duration(hours: 1),
      );
      final DateTime agora = DateTime(2026, 4, 20);
      final DashboardResumo resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Internet',
          valor: 120,
          data: DateTime(2026, 4, 2),
          categoria: CategoriaGasto.moradia,
        ),
      ], const <Conta>[]);

      final DashboardResumoCalculado entrada1 = service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.hoje,
        agora: agora,
      );
      service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.seteDias,
        agora: agora,
      );
      service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.mes,
        agora: agora,
      );

      final DashboardResumoCalculado entrada1Recalculada = service
          .calcularResumo(
            resumo: resumo,
            periodo: DashboardPeriodoRapido.hoje,
            agora: agora,
          );

      expect(identical(entrada1, entrada1Recalculada), isFalse);
      expect(service.cacheEntryCount <= 2, isTrue);
    });

    test('limpa cache manualmente', () {
      final DashboardSummaryService service = DashboardSummaryService();
      final DateTime agora = DateTime(2026, 4, 20);
      final DashboardResumo resumo = DashboardResumo(<Gasto>[
        Gasto(
          id: 'g1',
          titulo: 'Conta de luz',
          valor: 180,
          data: DateTime(2026, 4, 2),
          categoria: CategoriaGasto.moradia,
        ),
      ], const <Conta>[]);

      final DashboardResumoCalculado primeiro = service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.mes,
        agora: agora,
      );
      service.clearCache();
      final DashboardResumoCalculado segundo = service.calcularResumo(
        resumo: resumo,
        periodo: DashboardPeriodoRapido.mes,
        agora: agora,
      );

      expect(identical(primeiro, segundo), isFalse);
    });
  });
}
