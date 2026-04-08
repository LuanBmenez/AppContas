import 'dart:math';

import 'package:paga_o_que_me_deve/core/utils/app_formatters.dart';
import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
import 'package:paga_o_que_me_deve/domain/models/cartao_credito.dart';
import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';

enum CampoExtrato { dataLancamento, dataCompra, descricao, valor, parcela }

class LinhaExtratoCsv {
  final Map<String, String> colunas;

  const LinhaExtratoCsv({required this.colunas});
}

class ResultadoLeituraCsv {
  final List<String> cabecalhos;
  final List<LinhaExtratoCsv> linhas;

  const ResultadoLeituraCsv({required this.cabecalhos, required this.linhas});
}

class ResultadoMapeamentoExtrato {
  final List<Gasto> gastos;
  final List<RecebimentoDetectado> recebimentosDetectados;
  final int ignorados;
  final Map<String, int> ignoradosPorMotivo;
  final Map<String, int> categoriasPorFonte;
  final List<String> possiveisErros;
  final List<String> amostraLinhasIgnoradas;

  const ResultadoMapeamentoExtrato({
    required this.gastos,
    this.recebimentosDetectados = const <RecebimentoDetectado>[],
    required this.ignorados,
    this.ignoradosPorMotivo = const <String, int>{},
    this.categoriasPorFonte = const <String, int>{},
    this.possiveisErros = const <String>[],
    this.amostraLinhasIgnoradas = const <String>[],
  });
}

enum TipoRecebimentoDetectado {
  pixRecebido,
  transferenciaRecebida,
  reembolso,
  estorno,
  outro,
}

extension TipoRecebimentoDetectadoLabel on TipoRecebimentoDetectado {
  String get label {
    switch (this) {
      case TipoRecebimentoDetectado.pixRecebido:
        return 'Pix recebido';
      case TipoRecebimentoDetectado.transferenciaRecebida:
        return 'Transferencia recebida';
      case TipoRecebimentoDetectado.reembolso:
        return 'Reembolso';
      case TipoRecebimentoDetectado.estorno:
        return 'Estorno/Ajuste';
      case TipoRecebimentoDetectado.outro:
        return 'Outro recebimento';
    }
  }
}

class RecebimentoDetectado {
  final String id;
  final DateTime data;
  final double valor;
  final String descricaoOriginal;
  final String? nomeExtraido;
  final TipoRecebimentoDetectado tipo;
  final bool valorSuspeito;
  final String referenciaImportacao;

  const RecebimentoDetectado({
    required this.id,
    required this.data,
    required this.valor,
    required this.descricaoOriginal,
    required this.nomeExtraido,
    required this.tipo,
    required this.valorSuspeito,
    required this.referenciaImportacao,
  });
}

class SugestaoVinculoRecebimento {
  final Conta conta;
  final double score;
  final bool nomeCompativel;
  final bool valorCompativel;
  final double diferencaValorAbsoluta;

  const SugestaoVinculoRecebimento({
    required this.conta,
    required this.score,
    required this.nomeCompativel,
    required this.valorCompativel,
    required this.diferencaValorAbsoluta,
  });
}

class CategoriaResolvida {
  final CategoriaGasto categoria;
  final String fonte;

  const CategoriaResolvida({required this.categoria, required this.fonte});
}

class SugestaoRegraCategoria {
  final String termo;
  final CategoriaGasto categoria;
  final int ocorrencias;

  const SugestaoRegraCategoria({
    required this.termo,
    required this.categoria,
    required this.ocorrencias,
  });
}

class _RegraPadraoNormalizada {
  final String termoNormalizado;
  final CategoriaGasto categoria;

  const _RegraPadraoNormalizada({
    required this.termoNormalizado,
    required this.categoria,
  });
}

class _RegraAprendidaNormalizada {
  final CategoriaGasto categoria;
  final String termoNormalizado;
  final Set<String> tokens;

  const _RegraAprendidaNormalizada({
    required this.categoria,
    required this.termoNormalizado,
    required this.tokens,
  });
}

class ExtratoCsvService {
  static const Map<String, CategoriaGasto> _regrasCategoria =
      <String, CategoriaGasto>{
        'UBER': CategoriaGasto.transporte,
        '99 ': CategoriaGasto.transporte,
        'IPIRANGA': CategoriaGasto.transporte,
        'Mercadinho Dois Irmaos': CategoriaGasto.comida,
        'Panificacao Ki Delicia': CategoriaGasto.comida,
        'Mp *Donjuan': CategoriaGasto.comida,
        'Pizzariaimpe': CategoriaGasto.comida,
        'SHELL': CategoriaGasto.transporte,
        'POSTO': CategoriaGasto.transporte,
        'IFOOD': CategoriaGasto.comida,
        'RESTAURANTE': CategoriaGasto.comida,
        'LANCHONETE': CategoriaGasto.comida,
        'MERCADO': CategoriaGasto.comida,
        'Ifd': CategoriaGasto.comida,
        'SUPERMERCADO': CategoriaGasto.comida,
        'DROGARIA': CategoriaGasto.saude,
        'FARMACIA': CategoriaGasto.saude,
        'NETFLIX': CategoriaGasto.entretenimento,
        'SPOTIFY': CategoriaGasto.entretenimento,
        'CINEMA': CategoriaGasto.entretenimento,
        'Shopping Aracaju': CategoriaGasto.entretenimento,
        'ALURA': CategoriaGasto.educacao,
        'UDEMY': CategoriaGasto.educacao,
        'UNIVERSIDADE': CategoriaGasto.educacao,
        'Lojas Imperador': CategoriaGasto.moradia,
        'Mundodoscolchoes': CategoriaGasto.moradia,
        'Galego': CategoriaGasto.moradia,
      };

  static final List<_RegraPadraoNormalizada> _regrasPadraoNormalizadas =
      _regrasCategoria.entries
          .map(
            (entry) => _RegraPadraoNormalizada(
              termoNormalizado: TextNormalizer.normalizeForSearch(entry.key),
              categoria: entry.value,
            ),
          )
          .where((entry) => entry.termoNormalizado.isNotEmpty)
          .toList(growable: false);

  ResultadoLeituraCsv lerCsv(String conteudo) {
    final List<String> linhasBrutas = conteudo
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (linhasBrutas.isEmpty) {
      return const ResultadoLeituraCsv(
        cabecalhos: <String>[],
        linhas: <LinhaExtratoCsv>[],
      );
    }

    final String separador = _detectarSeparador(linhasBrutas.first);
    final List<String> cabecalhos = _parseLinhaCsv(
      linhasBrutas.first,
      separador,
    ).map((header) => header.trim()).toList();

    final List<LinhaExtratoCsv> linhas = <LinhaExtratoCsv>[];

    for (int i = 1; i < linhasBrutas.length; i++) {
      final List<String> campos = _parseLinhaCsv(linhasBrutas[i], separador);
      final Map<String, String> mapa = <String, String>{};

      for (int j = 0; j < cabecalhos.length; j++) {
        final String valor = j < campos.length ? campos[j].trim() : '';
        mapa[cabecalhos[j]] = valor;
      }

      linhas.add(LinhaExtratoCsv(colunas: mapa));
    }

    return ResultadoLeituraCsv(cabecalhos: cabecalhos, linhas: linhas);
  }

  ResultadoMapeamentoExtrato mapearParaGastos({
    required ResultadoLeituraCsv csv,
    required Map<CampoExtrato, String?> mapeamento,
    required CartaoCredito cartao,
    List<RegraCategoriaImportacao> regrasAprendidas =
        const <RegraCategoriaImportacao>[],
  }) {
    final String? colunaDescricao = mapeamento[CampoExtrato.descricao];
    final String? colunaValor = mapeamento[CampoExtrato.valor];
    final String? colunaDataLancamento =
        mapeamento[CampoExtrato.dataLancamento];

    if (colunaDescricao == null ||
        colunaValor == null ||
        colunaDataLancamento == null) {
      return const ResultadoMapeamentoExtrato(
        gastos: <Gasto>[],
        ignorados: 0,
        ignoradosPorMotivo: <String, int>{},
      );
    }

    int ignorados = 0;
    final List<Gasto> gastos = <Gasto>[];
    final List<RecebimentoDetectado> recebimentosDetectados =
        <RecebimentoDetectado>[];
    final Map<String, int> ignoradosPorMotivo = <String, int>{};
    final Map<String, int> categoriasPorFonte = <String, int>{};
    final List<String> possiveisErros = <String>[];
    final List<String> amostraLinhasIgnoradas = <String>[];
    final Set<String> hashesNoArquivo = <String>{};
    final List<RegraCategoriaImportacao> regrasAprendidasOrdenadas =
        List<RegraCategoriaImportacao>.from(regrasAprendidas)
          ..sort((a, b) => b.termo.length.compareTo(a.termo.length));
    final List<_RegraAprendidaNormalizada> regrasAprendidasNormalizadas =
        regrasAprendidasOrdenadas
            .map((regra) {
              final String termoNormalizado = _normalizarTextoBusca(
                regra.termo,
              );
              return _RegraAprendidaNormalizada(
                categoria: regra.categoria,
                termoNormalizado: termoNormalizado,
                tokens: _tokensRelevantes(termoNormalizado),
              );
            })
            .where((regra) => regra.termoNormalizado.isNotEmpty)
            .toList(growable: false);

    void registrarPossivelErro(String mensagem) {
      if (!possiveisErros.contains(mensagem)) {
        possiveisErros.add(mensagem);
      }
    }

    void contarIgnorado(
      String motivo, {
      int? linhaCsv,
      String? descricao,
      String? valor,
      String? data,
    }) {
      ignorados++;
      ignoradosPorMotivo[motivo] = (ignoradosPorMotivo[motivo] ?? 0) + 1;

      if (amostraLinhasIgnoradas.length < 10) {
        final StringBuffer detalhe = StringBuffer();
        if (linhaCsv != null) {
          detalhe.write('Linha $linhaCsv');
        } else {
          detalhe.write('Linha');
        }
        detalhe.write(': $motivo');

        if ((descricao ?? '').trim().isNotEmpty) {
          detalhe.write(' | desc="${descricao!.trim()}"');
        }
        if ((valor ?? '').trim().isNotEmpty) {
          detalhe.write(' | valor="$valor"');
        }
        if ((data ?? '').trim().isNotEmpty) {
          detalhe.write(' | data="$data"');
        }

        amostraLinhasIgnoradas.add(detalhe.toString());
      }
    }

    for (int idx = 0; idx < csv.linhas.length; idx++) {
      final LinhaExtratoCsv linha = csv.linhas[idx];
      final int linhaCsv = idx + 2;

      final String descricao = (linha.colunas[colunaDescricao] ?? '').trim();
      if (descricao.isEmpty) {
        contarIgnorado('Descricao vazia', linhaCsv: linhaCsv);
        continue;
      }

      final String valorRaw = linha.colunas[colunaValor] ?? '';
      final double? valor = _parseValor(valorRaw);
      if (valor == null) {
        contarIgnorado(
          'Valor invalido',
          linhaCsv: linhaCsv,
          descricao: descricao,
          valor: valorRaw,
        );
        continue;
      }

      final String dataLancamentoRaw =
          linha.colunas[colunaDataLancamento] ?? '';
      final DateTime? dataLancamento = _parseData(dataLancamentoRaw);

      if (dataLancamento == null) {
        contarIgnorado(
          'Data de lancamento invalida',
          linhaCsv: linhaCsv,
          descricao: descricao,
          data: dataLancamentoRaw,
        );
        continue;
      }

      if (valor > 0 && _ehPossivelRecebimento(descricao)) {
        final DateTime dataBase = dataLancamento;
        final TipoRecebimentoDetectado tipo = _classificarRecebimento(
          descricao,
        );
        final String? nomeExtraido = _extrairNomeContraparte(descricao);
        final String hashRecebimento = _hashImportacao(
          cartaoId: cartao.id,
          data: dataBase,
          descricao: descricao,
          valor: valor,
        );

        // CORREÇÃO: Evita duplicar o mesmo recebimento caso venha repetido no CSV
        if (!hashesNoArquivo.add(hashRecebimento)) {
          contarIgnorado(
            'Recebimento duplicado no arquivo',
            linhaCsv: linhaCsv,
            descricao: descricao,
            valor: valorRaw,
          );
          continue;
        }

        recebimentosDetectados.add(
          RecebimentoDetectado(
            id: hashRecebimento,
            data: dataBase,
            valor: valor,
            descricaoOriginal: descricao,
            nomeExtraido: nomeExtraido,
            tipo: tipo,
            valorSuspeito: valor <= 0.01,
            referenciaImportacao: hashRecebimento,
          ),
        );
        continue;
      }

      final String? colunaDataCompra = mapeamento[CampoExtrato.dataCompra];
      final String? colunaParcela = mapeamento[CampoExtrato.parcela];

      final DateTime? dataCompra = colunaDataCompra == null
          ? null
          : _parseData(linha.colunas[colunaDataCompra] ?? '');

      if (colunaDataCompra != null) {
        final String dataCompraRaw = linha.colunas[colunaDataCompra] ?? '';
        if (dataCompraRaw.trim().isNotEmpty && dataCompra == null) {
          registrarPossivelErro(
            'Algumas linhas possuem data de compra invalida; foi usada a data de lancamento.',
          );
        }
      }

      final String textoParcela = colunaParcela == null
          ? descricao
          : '${linha.colunas[colunaParcela] ?? ''} $descricao';
      final ({int atual, int total})? parcela = _extrairParcela(textoParcela);

      final bool ehEstorno = _ehEstornoOuAjuste(descricao);
      final double valorNormalizado = ehEstorno ? -valor.abs() : valor;
      final CategoriaResolvida categoriaResolvida = _categorizar(
        descricao,
        regrasAprendidasNormalizadas,
      );
      categoriasPorFonte[categoriaResolvida.fonte] =
          (categoriasPorFonte[categoriaResolvida.fonte] ?? 0) + 1;

      final DateTime dataCompetencia = _calcularDataCompetenciaFatura(
        dataCompra ?? dataLancamento,
        cartao.diaFechamento,
      );
      final DateTime dataBase = dataCompra ?? dataLancamento;
      final String hash = _hashImportacao(
        cartaoId: cartao.id,
        data: dataBase,
        descricao: descricao,
        valor: valorNormalizado,
      );

      if (!hashesNoArquivo.add(hash)) {
        contarIgnorado(
          'Gasto duplicado no arquivo',
          linhaCsv: linhaCsv,
          descricao: descricao,
          valor: valorRaw,
        );
        continue;
      }

      gastos.add(
        Gasto(
          id: '',
          titulo: descricao,
          valor: valorNormalizado,
          data: dataCompetencia,
          dataCompra: dataCompra,
          dataLancamento: dataLancamento,
          categoria: categoriaResolvida.categoria,
          tipo: TipoGasto.variavel,
          origem: OrigemGasto.cartaoCredito,
          cartaoId: cartao.id,
          cartaoNome: cartao.nome,
          hashImportacao: hash,
          parcelaAtual: parcela?.atual,
          parcelaTotal: parcela?.total,
        ),
      );
    }

    return ResultadoMapeamentoExtrato(
      gastos: gastos,
      recebimentosDetectados: recebimentosDetectados,
      ignorados: ignorados,
      ignoradosPorMotivo: ignoradosPorMotivo,
      categoriasPorFonte: categoriasPorFonte,
      possiveisErros: possiveisErros,
      amostraLinhasIgnoradas: amostraLinhasIgnoradas,
    );
  }

  Map<String, List<SugestaoVinculoRecebimento>> sugerirVinculosRecebimentos({
    required List<RecebimentoDetectado> recebimentos,
    required List<Conta> contasPendentes,
  }) {
    final Map<String, List<SugestaoVinculoRecebimento>> resultado =
        <String, List<SugestaoVinculoRecebimento>>{};

    for (final RecebimentoDetectado recebimento in recebimentos) {
      resultado[recebimento.id] = sugerirVinculosParaRecebimento(
        recebimento: recebimento,
        contasPendentes: contasPendentes,
      );
    }

    return resultado;
  }

  List<SugestaoVinculoRecebimento> sugerirVinculosParaRecebimento({
    required RecebimentoDetectado recebimento,
    required List<Conta> contasPendentes,
    int limite = 3,
  }) {
    final List<SugestaoVinculoRecebimento> sugestoes =
        <SugestaoVinculoRecebimento>[];
    final String nomeDetectado = _normalizarTextoBusca(
      recebimento.nomeExtraido ?? '',
    );

    for (final Conta conta in contasPendentes) {
      if (conta.foiPago) {
        continue;
      }

      final String nomeConta = _normalizarTextoBusca(conta.nome);
      final String descricaoConta = _normalizarTextoBusca(conta.descricao);
      final double nomeScore = nomeDetectado.isEmpty
          ? 0
          : max(
              _jaccard(
                _tokensRelevantes(nomeDetectado),
                _tokensRelevantes(nomeConta),
              ),
              _jaccard(
                _tokensRelevantes(nomeDetectado),
                _tokensRelevantes(descricaoConta),
              ),
            );

      // Forçando conversão de ambos para positivo a fim de evitar bugs no cálculo de diferença
      final double diferenca = (conta.valor.abs() - recebimento.valor.abs())
          .abs();
      final double toleranciaValor = max(5, recebimento.valor.abs() * 0.15);
      final bool valorCompativel = diferenca <= toleranciaValor;
      final double valorScore =
          (1 - (diferenca / max(recebimento.valor.abs(), 1))).clamp(0, 1);
      final double score = nomeDetectado.isEmpty
          ? valorScore * 0.6
          : (nomeScore * 0.65) + (valorScore * 0.35);

      if (nomeScore >= 0.45 || valorCompativel) {
        sugestoes.add(
          SugestaoVinculoRecebimento(
            conta: conta,
            score: score,
            nomeCompativel: nomeScore >= 0.45,
            valorCompativel: valorCompativel,
            diferencaValorAbsoluta: diferenca,
          ),
        );
      }
    }

    sugestoes.sort((a, b) => b.score.compareTo(a.score));
    return sugestoes.take(limite).toList();
  }

  List<SugestaoRegraCategoria> sugerirRegrasParaGastos({
    required List<Gasto> gastos,
    required List<RegraCategoriaImportacao> regrasExistentes,
    int minimoOcorrencias = 2,
  }) {
    final Set<String> regrasJaAprendidas = regrasExistentes
        .map((r) => _normalizarTextoBusca(r.termo))
        .where((termo) => termo.isNotEmpty)
        .toSet();

    final Map<String, String> termoOriginalPorChave = <String, String>{};
    final Map<String, int> ocorrenciasPorChave = <String, int>{};
    final Map<String, Map<CategoriaGasto, int>> votosPorChave =
        <String, Map<CategoriaGasto, int>>{};

    for (final Gasto gasto in gastos) {
      if (gasto.categoria == CategoriaGasto.outros) {
        continue;
      }

      final String termoOriginal = gasto.titulo.trim();
      final String chave = _normalizarTextoBusca(termoOriginal);
      if (chave.isEmpty ||
          chave.length < 3 ||
          regrasJaAprendidas.contains(chave)) {
        continue;
      }

      termoOriginalPorChave.putIfAbsent(chave, () => termoOriginal);
      ocorrenciasPorChave[chave] = (ocorrenciasPorChave[chave] ?? 0) + 1;
      final Map<CategoriaGasto, int> votos = votosPorChave.putIfAbsent(
        chave,
        () => <CategoriaGasto, int>{},
      );
      votos[gasto.categoria] = (votos[gasto.categoria] ?? 0) + 1;
    }

    final List<SugestaoRegraCategoria> sugestoes = <SugestaoRegraCategoria>[];
    for (final MapEntry<String, int> entry in ocorrenciasPorChave.entries) {
      if (entry.value < minimoOcorrencias) {
        continue;
      }

      final Map<CategoriaGasto, int> votos =
          votosPorChave[entry.key] ?? const <CategoriaGasto, int>{};
      if (votos.isEmpty) {
        continue;
      }

      final List<MapEntry<CategoriaGasto, int>> ranking = votos.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final MapEntry<CategoriaGasto, int> vencedor = ranking.first;

      sugestoes.add(
        SugestaoRegraCategoria(
          termo: termoOriginalPorChave[entry.key] ?? entry.key,
          categoria: vencedor.key,
          ocorrencias: entry.value,
        ),
      );
    }

    sugestoes.sort((a, b) => b.ocorrencias.compareTo(a.ocorrencias));
    return sugestoes;
  }

  String _detectarSeparador(String linha) {
    final int qtdPontoVirgula = ';'.allMatches(linha).length;
    final int qtdVirgula = ','.allMatches(linha).length;
    return qtdPontoVirgula >= qtdVirgula ? ';' : ',';
  }

  List<String> _parseLinhaCsv(String linha, String separador) {
    final List<String> valores = <String>[];
    final StringBuffer atual = StringBuffer();
    bool entreAspas = false;

    for (int i = 0; i < linha.length; i++) {
      final String char = linha[i];

      if (char == '"') {
        if (entreAspas && i + 1 < linha.length && linha[i + 1] == '"') {
          atual.write('"');
          i++;
        } else {
          entreAspas = !entreAspas;
        }
        continue;
      }

      if (!entreAspas && char == separador) {
        valores.add(atual.toString());
        atual.clear();
        continue;
      }

      atual.write(char);
    }

    valores.add(atual.toString());
    return valores;
  }

  DateTime? _parseData(String valor) {
    final String v = valor.trim();
    if (v.isEmpty) {
      return null;
    }

    final DateTime? iso = DateTime.tryParse(v);
    if (iso != null) {
      return iso;
    }

    final Match? br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(v);
    if (br != null) {
      final int dia = int.parse(br.group(1)!);
      final int mes = int.parse(br.group(2)!);
      final int ano = int.parse(br.group(3)!);
      return DateTime(ano, mes, dia);
    }

    final Match? brCurto = RegExp(r'^(\d{2})/(\d{2})/(\d{2})$').firstMatch(v);
    if (brCurto != null) {
      final int dia = int.parse(brCurto.group(1)!);
      final int mes = int.parse(brCurto.group(2)!);
      final int ano = 2000 + int.parse(brCurto.group(3)!);
      return DateTime(ano, mes, dia);
    }

    return null;
  }

  double? _parseValor(String valor) {
    final String limpo = valor.trim();
    if (limpo.isEmpty) {
      return null;
    }

    final String bruto = limpo
        .replaceAll(RegExp(r'R\$'), '')
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^0-9,.-]'), '');

    if (bruto.isEmpty) {
      return null;
    }

    final int ultimoPonto = bruto.lastIndexOf('.');
    final int ultimaVirgula = bruto.lastIndexOf(',');

    String normalizado;
    if (ultimoPonto >= 0 && ultimaVirgula >= 0) {
      if (ultimoPonto > ultimaVirgula) {
        normalizado = bruto.replaceAll(',', '');
      } else {
        normalizado = bruto.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (ultimaVirgula >= 0) {
      normalizado = bruto.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalizado = bruto;
    }

    final double? valorDireto = double.tryParse(normalizado);
    if (valorDireto != null) {
      return valorDireto;
    }

    try {
      return AppFormatters.parseMoedaInput(limpo);
    } catch (_) {
      return null;
    }
  }

  ({int atual, int total})? _extrairParcela(String texto) {
    final Match? match = RegExp(r'(\d{1,2})\s*/\s*(\d{1,2})').firstMatch(texto);
    if (match == null) {
      return null;
    }

    final int? atual = int.tryParse(match.group(1)!);
    final int? total = int.tryParse(match.group(2)!);

    if (atual == null ||
        total == null ||
        atual < 1 ||
        total < 1 ||
        atual > total) {
      return null;
    }

    return (atual: atual, total: total);
  }

  bool _ehEstornoOuAjuste(String descricao) {
    final String d = descricao.toUpperCase();
    return d.contains('ESTORNO') ||
        d.contains('CHARGEBACK') ||
        d.contains('AJUSTE') ||
        d.contains('REVERSAO');
  }

  DateTime _calcularDataCompetenciaFatura(DateTime data, int diaFechamento) {
    if (data.day <= diaFechamento) {
      return DateTime(data.year, data.month, data.day);
    }

    int anoCompetencia = data.year;
    int mesCompetencia = data.month + 1;
    if (mesCompetencia > DateTime.december) {
      mesCompetencia = DateTime.january;
      anoCompetencia++;
    }

    final int ultimoDiaMesCompetencia = DateTime(
      anoCompetencia,
      mesCompetencia + 1,
      0,
    ).day;
    final int diaCompetencia = data.day <= ultimoDiaMesCompetencia
        ? data.day
        : ultimoDiaMesCompetencia;

    return DateTime(anoCompetencia, mesCompetencia, diaCompetencia);
  }

  TipoRecebimentoDetectado _classificarRecebimento(String descricao) {
    // CORREÇÃO: Força o toUpperCase() para o match exato das palavras-chave,
    // independente do comportamento interno do TextNormalizer.
    final String d = _normalizarTextoBusca(descricao).toUpperCase();

    if (d.contains('REEMBOLSO')) {
      return TipoRecebimentoDetectado.reembolso;
    }

    if (d.contains('ESTORNO') ||
        d.contains('CHARGEBACK') ||
        d.contains('REVERSAO') ||
        d.contains('AJUSTE')) {
      return TipoRecebimentoDetectado.estorno;
    }

    if (d.contains('PIX')) {
      return TipoRecebimentoDetectado.pixRecebido;
    }

    if (d.contains('TRANSFERENCIA') || d.contains('TED') || d.contains('DOC')) {
      return TipoRecebimentoDetectado.transferenciaRecebida;
    }

    return TipoRecebimentoDetectado.outro;
  }

  bool _ehPossivelRecebimento(String descricao) {
    final TipoRecebimentoDetectado tipo = _classificarRecebimento(descricao);
    if (tipo != TipoRecebimentoDetectado.outro) {
      return true;
    }

    // CORREÇÃO: Força o toUpperCase() para proteção do comportamento do Normalizer.
    final String d = _normalizarTextoBusca(descricao).toUpperCase();
    return d.contains('RECEBIDO') ||
        d.contains('RECEBIMENTO') ||
        d.contains('CREDITO RECEBIDO') ||
        d.contains('DEPOSITO RECEBIDO');
  }

  String? _extrairNomeContraparte(String descricao) {
    final List<String> partes = descricao.split('-');
    if (partes.length < 2) {
      return null;
    }

    final String candidata = partes.sublist(1).join(' ').trim();
    if (candidata.isEmpty) {
      return null;
    }

    final Match? match = RegExp(
      r'([A-Za-zÀ-ÿ]{2,}(?:\s+[A-Za-zÀ-ÿ]{2,}){0,5})',
    ).firstMatch(candidata);
    if (match == null) {
      return null;
    }

    final String nome = _normalizarTextoBusca(match.group(1) ?? '');
    return nome.isEmpty ? null : nome;
  }

  String _normalizarTextoBusca(String texto) =>
      TextNormalizer.normalizeForSearch(texto);

  CategoriaResolvida _categorizar(
    String descricao,
    List<_RegraAprendidaNormalizada> regrasAprendidas,
  ) {
    final String d = _normalizarTextoBusca(descricao);
    final Set<String> tokensDescricao = _tokensRelevantes(d);

    for (final _RegraAprendidaNormalizada regra in regrasAprendidas) {
      if (d.contains(regra.termoNormalizado)) {
        return CategoriaResolvida(
          categoria: regra.categoria,
          fonte: 'historico_exato',
        );
      }
    }

    double melhorScore = 0;
    CategoriaGasto? melhorCategoria;
    for (final _RegraAprendidaNormalizada regra in regrasAprendidas) {
      final Set<String> tokensRegra = regra.tokens;
      if (tokensRegra.isEmpty || tokensDescricao.isEmpty) {
        continue;
      }

      final double score = _jaccard(tokensDescricao, tokensRegra);
      if (score > melhorScore) {
        melhorScore = score;
        melhorCategoria = regra.categoria;
      }
    }

    if (melhorCategoria != null && melhorScore >= 0.6) {
      return CategoriaResolvida(
        categoria: melhorCategoria,
        fonte: 'historico_aproximado',
      );
    }

    for (final _RegraPadraoNormalizada entry in _regrasPadraoNormalizadas) {
      if (d.contains(entry.termoNormalizado)) {
        return CategoriaResolvida(
          categoria: entry.categoria,
          fonte: 'regra_padrao',
        );
      }
    }

    return const CategoriaResolvida(
      categoria: CategoriaGasto.outros,
      fonte: 'fallback_outros',
    );
  }

  Set<String> _tokensRelevantes(String valor) {
    return valor
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.length >= 3)
        .toSet();
  }

  double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }

    final Set<String> inter = a.intersection(b);
    final Set<String> uniao = a.union(b);
    if (uniao.isEmpty) {
      return 0;
    }
    return inter.length / uniao.length;
  }

  String _hashImportacao({
    required String cartaoId,
    required DateTime data,
    required String descricao,
    required double valor,
  }) {
    final String base =
        '$cartaoId|${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}|${descricao.trim().toUpperCase()}|${valor.toStringAsFixed(2)}';
    return _fnv1a64(base);
  }

  String _fnv1a64(String value) {
    const int offset = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    const int mask64 = 0xFFFFFFFFFFFFFFFF;

    int hash = offset;
    for (final int byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * prime) & mask64;
    }

    final String hex = hash.toRadixString(16);
    return hex.padLeft(max(16, hex.length), '0');
  }
}
