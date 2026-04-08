import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/domain/models/categoria_personalizada.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';
import 'package:paga_o_que_me_deve/features/gastos/presentation/controllers/novo_gasto_categoria_controller.dart';

void main() {
  group('NovoGastoCategoriaController', () {
    test('prioriza regra aprendida sobre sugestao padrao', () {
      final CategoriaSugestaoResultado resultado =
          NovoGastoCategoriaController.sugerirPorTitulo(
            titulo: 'Amazon marketplace pedido 123',
            categoriasAtivas: const <CategoriaPersonalizada>[],
            regrasAprendidas: const <RegraCategoriaImportacao>[
              RegraCategoriaImportacao(
                id: 'amazon',
                termo: 'amazon',
                categoria: CategoriaGasto.entretenimento,
              ),
            ],
          );

      expect(resultado.categoriaPadrao, CategoriaGasto.entretenimento);
      expect(resultado.categoriaPersonalizadaId, isNull);
    });

    test('prioriza categoria personalizada quando titulo contem nome', () {
      const CategoriaPersonalizada personalizada = CategoriaPersonalizada(
        id: 'cat1',
        nome: 'Casa',
        corValue: 0xFF0D9488,
        iconeCodePoint: 0xe88a,
      );

      final CategoriaSugestaoResultado resultado =
          NovoGastoCategoriaController.sugerirPorTitulo(
            titulo: 'Conta casa energisa',
            categoriasAtivas: const <CategoriaPersonalizada>[personalizada],
            regrasAprendidas: const <RegraCategoriaImportacao>[
              RegraCategoriaImportacao(
                id: 'energisa',
                termo: 'energisa',
                categoria: CategoriaGasto.moradia,
              ),
            ],
          );

      expect(resultado.categoriaPersonalizadaId, 'cat1');
      expect(resultado.categoriaPadrao, isNull);
    });
  });
}
