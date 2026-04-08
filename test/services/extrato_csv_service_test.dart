import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/domain/models/cartao_credito.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/extrato_csv_service.dart';

void main() {
  group('ExtratoCsvService', () {
    const CartaoCredito cartao = CartaoCredito(
      id: 'c1',
      nome: 'Meu Cartao',
      finalCartao: '1234',
      diaFechamento: 10,
      diaVencimento: 20,
    );

    test('deve ignorar duplicados no mesmo arquivo', () {
      final ExtratoCsvService service = ExtratoCsvService();
      final ResultadoLeituraCsv csv = service.lerCsv(
        'data;descricao;valor\n'
        '01/03/2026;IFOOD PEDIDO;45,50\n'
        '01/03/2026;IFOOD PEDIDO;45,50\n',
      );

      final ResultadoMapeamentoExtrato resultado = service.mapearParaGastos(
        csv: csv,
        mapeamento: <CampoExtrato, String?>{
          CampoExtrato.dataLancamento: 'data',
          CampoExtrato.descricao: 'descricao',
          CampoExtrato.valor: 'valor',
        },
        cartao: cartao,
      );

      expect(resultado.gastos, hasLength(1));
      expect(resultado.ignorados, 1);
      expect(resultado.ignoradosPorMotivo['Duplicado no arquivo'], 1);
    });

    test('deve usar regra aprendida exata para categorizar', () {
      final ExtratoCsvService service = ExtratoCsvService();
      final ResultadoLeituraCsv csv = service.lerCsv(
        'data;descricao;valor\n'
        '02/03/2026;Padaria Boa Massa;30,00\n',
      );

      final ResultadoMapeamentoExtrato resultado = service.mapearParaGastos(
        csv: csv,
        mapeamento: <CampoExtrato, String?>{
          CampoExtrato.dataLancamento: 'data',
          CampoExtrato.descricao: 'descricao',
          CampoExtrato.valor: 'valor',
        },
        cartao: cartao,
        regrasAprendidas: const <RegraCategoriaImportacao>[
          RegraCategoriaImportacao(
            id: 'r1',
            termo: 'Padaria Boa Massa',
            categoria: CategoriaGasto.comida,
          ),
        ],
      );

      expect(resultado.gastos, hasLength(1));
      expect(resultado.gastos.first.categoria, CategoriaGasto.comida);
      expect(resultado.categoriasPorFonte['historico_exato'], 1);
    });
  });
}
