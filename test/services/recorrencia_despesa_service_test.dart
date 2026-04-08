import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/features/gastos/data/services/recorrencia_despesa_service.dart';

void main() {
  group('RecorrenciaDespesaService', () {
    const RecorrenciaDespesaService service = RecorrenciaDespesaService();

    Gasto gasto(DateTime data, double valor) {
      return Gasto(
        id: '',
        titulo: 'Netflix assinatura',
        valor: valor,
        data: data,
        categoria: CategoriaGasto.entretenimento,
        tipo: TipoGasto.fixo,
      );
    }

    test('detecta recorrencia mensal com historico consistente', () {
      final sugestao = service.detectarMensal(<Gasto>[
        gasto(DateTime(2026, 1, 10), 39.90),
        gasto(DateTime(2026, 2, 10), 39.90),
        gasto(DateTime(2026, 3, 10), 39.90),
        gasto(DateTime(2026, 4, 10), 39.90),
      ]);

      expect(sugestao, isNotNull);
      expect(sugestao!.periodicidade, 'mensal');
      expect(sugestao.ocorrencias, 4);
      expect(sugestao.diaPreferencial, 10);
    });

    test('nao detecta quando historico e irregular', () {
      final sugestao = service.detectarMensal(<Gasto>[
        gasto(DateTime(2026, 1, 2), 20),
        gasto(DateTime(2026, 1, 20), 55),
        gasto(DateTime(2026, 3, 5), 18),
      ]);

      expect(sugestao, isNull);
    });
  });
}
