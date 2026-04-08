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

  Future<void> vincularRecebimentoImportado({
    required Conta conta,
    required String referencia,
    required DateTime dataRecebimento,
    required double valorRecebido,
  }) async {
    if (!conta.foiPago) {
      await _repository.alternarStatusRecebivel(conta.id, conta.foiPago);
    }

    final String detalhe =
        'Recebimento via importacao CSV em ${AppFormatters.dataCurta(dataRecebimento)} (${AppFormatters.moeda(valorRecebido)}).';
    final String descricaoAtualizada = _anexarDetalhesNaDescricao(
      conta.descricao,
      detalhe,
      referencia,
    );

    await _repository.atualizarRecebivel(
      conta.copyWith(descricao: descricaoAtualizada),
    );
  }

  Future<void> criarRecebimentoAvulso({
    required String nome,
    required String descricao,
    required DateTime data,
    required double valor,
  }) {
    return _repository.adicionarRecebivel(
      Conta(
        id: '',
        nome: nome,
        descricao: descricao,
        valor: valor,
        data: data,
        foiPago: true,
        recebidaEm: data,
      ),
    );
  }

  String _anexarDetalhesNaDescricao(
    String descricaoAtual,
    String detalhe,
    String referencia,
  ) {
    final String referenciaLimpa = referencia.trim();
    final String descricaoBase = descricaoAtual.trim();
    final String marcador = '[Importacao CSV]';
    if (descricaoBase.contains(marcador)) {
      return descricaoBase;
    }

    final String referenciaCurta = referenciaLimpa.length > 120
        ? '${referenciaLimpa.substring(0, 120)}...'
        : referenciaLimpa;
    final String bloco =
        '$marcador $detalhe${referenciaCurta.isEmpty ? '' : ' Ref: $referenciaCurta'}';
    if (descricaoBase.isEmpty) {
      return bloco;
    }

    return '$descricaoBase\n$bloco';
  }
}
