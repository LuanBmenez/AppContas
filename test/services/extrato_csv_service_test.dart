import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/domain/models/cartao_credito.dart';
import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/extrato_csv_service.dart';

void main() {
  group('ExtratoCsvService', () {
    const cartao = CartaoCredito(
      id: 'c1',
      nome: 'Meu Cartao',
      finalCartao: '1234',
      diaFechamento: 10,
      diaVencimento: 20,
    );

    test('deve ignorar duplicados no mesmo arquivo', () {
      final service = ExtratoCsvService();
      final csv = service.lerCsv(
        'data;descricao;valor\n'
        '01/03/2026;IFOOD PEDIDO;45,50\n'
        '01/03/2026;IFOOD PEDIDO;45,50\n',
      );

      final resultado = service.mapearParaGastos(
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
      final service = ExtratoCsvService();
      final csv = service.lerCsv(
        'data;descricao;valor\n'
        '02/03/2026;Padaria Boa Massa;30,00\n',
      );

      final resultado = service.mapearParaGastos(
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

    test('deve manter no mesmo mes quando compra for antes do fechamento', () {
      final service = ExtratoCsvService();
      final csv = service.lerCsv(
        'data;descricao;valor\n'
        '09/03/2026;Farmacia;25,00\n',
      );

      final resultado = service.mapearParaGastos(
        csv: csv,
        mapeamento: <CampoExtrato, String?>{
          CampoExtrato.dataLancamento: 'data',
          CampoExtrato.descricao: 'descricao',
          CampoExtrato.valor: 'valor',
        },
        cartao: cartao,
      );

      expect(resultado.gastos, hasLength(1));
      expect(resultado.gastos.first.data, DateTime(2026, 3, 9));
    });

    test('deve manter no mesmo mes quando compra for no dia do fechamento', () {
      final service = ExtratoCsvService();
      final csv = service.lerCsv(
        'data;descricao;valor\n'
        '10/03/2026;Supermercado;100,00\n',
      );

      final resultado = service.mapearParaGastos(
        csv: csv,
        mapeamento: <CampoExtrato, String?>{
          CampoExtrato.dataLancamento: 'data',
          CampoExtrato.descricao: 'descricao',
          CampoExtrato.valor: 'valor',
        },
        cartao: cartao,
      );

      expect(resultado.gastos, hasLength(1));
      expect(resultado.gastos.first.data, DateTime(2026, 3, 10));
    });

    test('deve ir para o mes seguinte quando compra for apos fechamento', () {
      final service = ExtratoCsvService();
      final csv = service.lerCsv(
        'data;descricao;valor\n'
        '11/03/2026;Assinatura;39,90\n',
      );

      final resultado = service.mapearParaGastos(
        csv: csv,
        mapeamento: <CampoExtrato, String?>{
          CampoExtrato.dataLancamento: 'data',
          CampoExtrato.descricao: 'descricao',
          CampoExtrato.valor: 'valor',
        },
        cartao: cartao,
      );

      expect(resultado.gastos, hasLength(1));
      expect(resultado.gastos.first.data, DateTime(2026, 4, 11));
    });

    test(
      'deve ajustar para o ultimo dia quando o proximo mes nao tiver o mesmo dia',
      () {
        final service = ExtratoCsvService();
        final csv = service.lerCsv(
          'data;descricao;valor\n'
          '31/03/2026;Compra pontual;50,00\n',
        );

        final resultado = service.mapearParaGastos(
          csv: csv,
          mapeamento: <CampoExtrato, String?>{
            CampoExtrato.dataLancamento: 'data',
            CampoExtrato.descricao: 'descricao',
            CampoExtrato.valor: 'valor',
          },
          cartao: cartao,
        );

        expect(resultado.gastos, hasLength(1));
        expect(resultado.gastos.first.data, DateTime(2026, 4, 30));
      },
    );

    test('deve virar dezembro para janeiro mantendo o dia quando valido', () {
      final service = ExtratoCsvService();
      final csv = service.lerCsv(
        'data;descricao;valor\n'
        '15/12/2026;Eletronicos;250,00\n',
      );

      final resultado = service.mapearParaGastos(
        csv: csv,
        mapeamento: <CampoExtrato, String?>{
          CampoExtrato.dataLancamento: 'data',
          CampoExtrato.descricao: 'descricao',
          CampoExtrato.valor: 'valor',
        },
        cartao: cartao,
      );

      expect(resultado.gastos, hasLength(1));
      expect(resultado.gastos.first.data, DateTime(2027, 1, 15));
    });

    test('deve detectar entrada positiva como recebimento e nao como gasto', () {
      final service = ExtratoCsvService();
      final csv = service.lerCsv(
        'data;descricao;valor\n'
        '03/03/2026;Transferencia recebida pelo Pix - LUCIANA BARROS VIEIRA;150,00\n'
        '04/03/2026;IFOOD PEDIDO;-40,00\n',
      );

      final resultado = service.mapearParaGastos(
        csv: csv,
        mapeamento: <CampoExtrato, String?>{
          CampoExtrato.dataLancamento: 'data',
          CampoExtrato.descricao: 'descricao',
          CampoExtrato.valor: 'valor',
        },
        cartao: cartao,
      );

      expect(resultado.gastos, hasLength(1));
      expect(resultado.recebimentosDetectados, hasLength(1));
      expect(
        resultado.recebimentosDetectados.first.tipo,
        TipoRecebimentoDetectado.pixRecebido,
      );
      expect(
        resultado.recebimentosDetectados.first.nomeExtraido,
        'LUCIANA BARROS VIEIRA',
      );
    });

    test('deve marcar valores muito baixos como suspeitos', () {
      final service = ExtratoCsvService();
      final csv = service.lerCsv(
        'data;descricao;valor\n'
        '05/03/2026;Transferencia Recebida;0,01\n',
      );

      final resultado = service.mapearParaGastos(
        csv: csv,
        mapeamento: <CampoExtrato, String?>{
          CampoExtrato.dataLancamento: 'data',
          CampoExtrato.descricao: 'descricao',
          CampoExtrato.valor: 'valor',
        },
        cartao: cartao,
      );

      expect(resultado.recebimentosDetectados, hasLength(1));
      expect(resultado.recebimentosDetectados.first.valorSuspeito, isTrue);
    });

    test('deve sugerir cobranca pendente com nome e valor compativeis', () {
      final service = ExtratoCsvService();
      final recebimento = RecebimentoDetectado(
        id: 'r1',
        data: DateTime(2026, 3, 3),
        valor: 150,
        descricaoOriginal:
            'Transferencia recebida pelo Pix - LUCIANA BARROS VIEIRA',
        nomeExtraido: 'LUCIANA BARROS VIEIRA',
        tipo: TipoRecebimentoDetectado.pixRecebido,
        valorSuspeito: false,
        referenciaImportacao: 'h1',
      );

      final pendentes = <Conta>[
        Conta(
          id: 'c1',
          nome: 'Luciana Barros Vieira',
          descricao: 'Servico prestado',
          valor: 150,
          data: DateTime(2026, 3),
        ),
        Conta(
          id: 'c2',
          nome: 'Outro Cliente',
          descricao: 'Projeto',
          valor: 150,
          data: DateTime(2026, 3),
        ),
      ];

      final sugestoes = service
          .sugerirVinculosParaRecebimento(
            recebimento: recebimento,
            contasPendentes: pendentes,
          );

      expect(sugestoes, isNotEmpty);
      expect(sugestoes.first.conta.id, 'c1');
      expect(sugestoes.first.valorCompativel, isTrue);
      expect(sugestoes.first.nomeCompativel, isTrue);
    });
  });
}
