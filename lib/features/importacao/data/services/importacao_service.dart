import 'package:paga_o_que_me_deve/core/utils/app_formatters.dart';
import 'package:paga_o_que_me_deve/domain/models/cartao_credito.dart';
import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class ImportacaoService {
  const ImportacaoService(this._repository);

  final FinanceRepository _repository;

  Stream<List<CartaoCredito>> get cartoesCredito => _repository.cartoesCredito;

  Stream<List<Conta>> get contasAReceber => _repository.contasAReceber;

  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao {
    return _repository.regrasCategoriaImportacao;
  }

  Future<ResultadoImportacaoGastos> importarGastosComDeduplicacao(
    List<Gasto> gastos,
  ) {
    return _repository.importarGastosComDeduplicacao(gastos);
  }

  Future<int> contarDuplicadosPorHash(List<String> hashes) {
    return _repository.contarDuplicadosPorHash(hashes);
  }

  Future<void> salvarRegraCategoriaImportacao({
    required String termo,
    required CategoriaGasto categoria,
  }) {
    return _repository.salvarRegraCategoriaImportacao(
      termo: termo,
      categoria: categoria,
    );
  }

  bool recebimentoJaImportado({
    required List<Conta> contas,
    required String referenciaImportacao,
  }) {
    final marcador = _marcadorImportacao(referenciaImportacao);

    return contas.any((conta) {
      final naDescricao = conta.descricao.contains(marcador);
      final noHistorico = conta.historico.any(
        (evento) => evento.descricao.contains(marcador),
      );
      return naDescricao || noHistorico;
    });
  }

  Future<void> vincularRecebimentoImportado({
    required Conta conta,
    required String referencia,
    required String referenciaImportacao,
    required DateTime dataRecebimento,
    required double valorRecebido,
  }) async {
    if (_descricaoJaContemImportacao(conta.descricao, referenciaImportacao)) {
      return;
    }

    final detalhe =
        'Recebimento via importacao CSV em ${AppFormatters.dataCurta(dataRecebimento)} '
        '(${AppFormatters.moeda(valorRecebido)}).';

    final descricaoAtualizada = _anexarDetalhesNaDescricao(
      conta.descricao,
      detalhe,
      referencia,
      referenciaImportacao,
    );

    await _repository.atualizarRecebivel(
      conta.copyWith(
        descricao: descricaoAtualizada,
        foiPago: true,
        recebidaEm: dataRecebimento,
      ),
    );
  }

  Future<void> criarRecebimentoAvulso({
    required String nome,
    required String descricao,
    required DateTime data,
    required double valor,
    required String referenciaImportacao,
  }) {
    final detalhe =
        'Recebimento via importacao CSV em ${AppFormatters.dataCurta(data)} '
        '(${AppFormatters.moeda(valor)}).';

    final descricaoFinal = _anexarDetalhesNaDescricao(
      descricao,
      detalhe,
      descricao,
      referenciaImportacao,
    );

    return _repository.adicionarRecebivel(
      Conta(
        id: '',
        nome: nome,
        descricao: descricaoFinal,
        valor: valor,
        data: data,
        foiPago: true,
        recebidaEm: data,
      ),
    );
  }

  bool _descricaoJaContemImportacao(
    String descricaoAtual,
    String referenciaImportacao,
  ) {
    return descricaoAtual.contains(_marcadorImportacao(referenciaImportacao));
  }

  String _marcadorImportacao(String referenciaImportacao) {
    return '[Importacao CSV ID:$referenciaImportacao]';
  }

  String _anexarDetalhesNaDescricao(
    String descricaoAtual,
    String detalhe,
    String referencia,
    String referenciaImportacao,
  ) {
    final descricaoBase = descricaoAtual.trim();
    final referenciaLimpa = referencia.trim();
    final marcador = _marcadorImportacao(referenciaImportacao);

    if (descricaoBase.contains(marcador)) {
      return descricaoBase;
    }

    final referenciaCurta = referenciaLimpa.length > 120
        ? '${referenciaLimpa.substring(0, 120)}...'
        : referenciaLimpa;

    final bloco =
        '$marcador $detalhe'
        '${referenciaCurta.isEmpty ? '' : ' Ref: $referenciaCurta'}';

    if (descricaoBase.isEmpty) {
      return bloco;
    }

    return '$descricaoBase\n$bloco';
  }
}
