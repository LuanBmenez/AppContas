import 'dart:math';

import 'package:paga_o_que_me_deve/core/utils/app_formatters.dart';
import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
import 'package:paga_o_que_me_deve/domain/models/cartao_credito.dart';
import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';

enum CampoExtrato { dataLancamento, dataCompra, descricao, valor, parcela }

class LinhaExtratoCsv {
  const LinhaExtratoCsv({required this.colunas});
  final Map<String, String> colunas;
}

class ResultadoLeituraCsv {
  const ResultadoLeituraCsv({required this.cabecalhos, required this.linhas});
  final List<String> cabecalhos;
  final List<LinhaExtratoCsv> linhas;
}

class ResultadoMapeamentoExtrato {
  const ResultadoMapeamentoExtrato({
    required this.gastos,
    required this.ignorados,
    this.recebimentosDetectados = const <RecebimentoDetectado>[],
    this.ignoradosPorMotivo = const <String, int>{},
    this.categoriasPorFonte = const <String, int>{},
    this.possiveisErros = const <String>[],
    this.amostraLinhasIgnoradas = const <String>[],
  });
  final List<Gasto> gastos;
  final List<RecebimentoDetectado> recebimentosDetectados;
  final int ignorados;
  final Map<String, int> ignoradosPorMotivo;
  final Map<String, int> categoriasPorFonte;
  final List<String> possiveisErros;
  final List<String> amostraLinhasIgnoradas;
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
  final String id;
  final DateTime data;
  final double valor;
  final String descricaoOriginal;
  final String? nomeExtraido;
  final TipoRecebimentoDetectado tipo;
  final bool valorSuspeito;
  final String referenciaImportacao;
}

class SugestaoVinculoRecebimento {
  const SugestaoVinculoRecebimento({
    required this.conta,
    required this.score,
    required this.nomeCompativel,
    required this.valorCompativel,
    required this.diferencaValorAbsoluta,
  });
  final Conta conta;
  final double score;
  final bool nomeCompativel;
  final bool valorCompativel;
  final double diferencaValorAbsoluta;
}

class CategoriaResolvida {
  const CategoriaResolvida({required this.categoria, required this.fonte});
  final CategoriaGasto categoria;
  final String fonte;
}

class SugestaoRegraCategoria {
  const SugestaoRegraCategoria({
    required this.termo,
    required this.categoria,
    required this.ocorrencias,
  });
  final String termo;
  final CategoriaGasto categoria;
  final int ocorrencias;
}

class _RegraPadraoNormalizada {
  const _RegraPadraoNormalizada({
    required this.termoNormalizado,
    required this.categoria,
  });
  final String termoNormalizado;
  final CategoriaGasto categoria;
}

class _RegraAprendidaNormalizada {
  const _RegraAprendidaNormalizada({
    required this.categoria,
    required this.termoNormalizado,
    required this.tokens,
  });
  final CategoriaGasto categoria;
  final String termoNormalizado;
  final Set<String> tokens;
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
    final linhasBrutas = conteudo
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

    final separador = _detectarSeparador(linhasBrutas.first);
    final cabecalhos = _parseLinhaCsv(
      linhasBrutas.first,
      separador,
    ).map((header) => header.trim()).toList();

    final linhas = <LinhaExtratoCsv>[];

    for (var i = 1; i < linhasBrutas.length; i++) {
      final campos = _parseLinhaCsv(linhasBrutas[i], separador);
      final mapa = <String, String>{};

      for (var j = 0; j < cabecalhos.length; j++) {
        final valor = j < campos.length ? campos[j].trim() : '';
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
    final colunaDescricao = mapeamento[CampoExtrato.descricao];
    final colunaValor = mapeamento[CampoExtrato.valor];
    final colunaDataLancamento = mapeamento[CampoExtrato.dataLancamento];

    if (colunaDescricao == null ||
        colunaValor == null ||
        colunaDataLancamento == null) {
      return const ResultadoMapeamentoExtrato(
        gastos: <Gasto>[],
        ignorados: 0,
      );
    }

    var ignorados = 0;
    final gastos = <Gasto>[];
    final recebimentosDetectados = <RecebimentoDetectado>[];
    final ignoradosPorMotivo = <String, int>{};
    final categoriasPorFonte = <String, int>{};
    final possiveisErros = <String>[];
    final amostraLinhasIgnoradas = <String>[];
    final hashesNoArquivo = <String>{};
    final regrasAprendidasOrdenadas = List<RegraCategoriaImportacao>.from(
      regrasAprendidas,
    )..sort((a, b) => b.termo.length.compareTo(a.termo.length));
    final regrasAprendidasNormalizadas = regrasAprendidasOrdenadas
        .map((regra) {
          final termoNormalizado = _normalizarTextoBusca(
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
        final detalhe = StringBuffer();
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

    for (var idx = 0; idx < csv.linhas.length; idx++) {
      final linha = csv.linhas[idx];
      final linhaCsv = idx + 2;

      final descricao = (linha.colunas[colunaDescricao] ?? '').trim();
      if (descricao.isEmpty) {
        contarIgnorado('Descricao vazia', linhaCsv: linhaCsv);
        continue;
      }

      final valorRaw = linha.colunas[colunaValor] ?? '';
      final valor = _parseValor(valorRaw);
      if (valor == null) {
        contarIgnorado(
          'Valor invalido',
          linhaCsv: linhaCsv,
          descricao: descricao,
          valor: valorRaw,
        );
        continue;
      }

      final dataLancamentoRaw = linha.colunas[colunaDataLancamento] ?? '';
      final dataLancamento = _parseData(dataLancamentoRaw);

      if (dataLancamento == null) {
        contarIgnorado(
          'Data de lancamento invalida',
          linhaCsv: linhaCsv,
          descricao: descricao,
          data: dataLancamentoRaw,
        );
        continue;
      }

      if (valor > 0) {
        final dataBase = dataLancamento;
        final tipo = _classificarRecebimento(
          descricao,
        );
        final nomeExtraido = _extrairNomeContraparte(descricao);
        final hashRecebimento = _hashImportacao(
          cartaoId: cartao.id,
          data: dataBase,
          descricao: descricao,
          valor: valor,
        );

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

      final colunaDataCompra = mapeamento[CampoExtrato.dataCompra];
      final colunaParcela = mapeamento[CampoExtrato.parcela];

      final dataCompra = colunaDataCompra == null
          ? null
          : _parseData(linha.colunas[colunaDataCompra] ?? '');

      if (colunaDataCompra != null) {
        final dataCompraRaw = linha.colunas[colunaDataCompra] ?? '';
        if (dataCompraRaw.trim().isNotEmpty && dataCompra == null) {
          registrarPossivelErro(
            'Algumas linhas possuem data de compra invalida; foi usada a data de lancamento.',
          );
        }
      }

      final textoParcela = colunaParcela == null
          ? descricao
          : '${linha.colunas[colunaParcela] ?? ''} $descricao';
      final parcela = _extrairParcela(textoParcela);

      final ehEstorno = _ehEstornoOuAjuste(descricao);
      final valorNormalizado = ehEstorno ? -valor.abs() : valor.abs();

      final categoriaResolvida = _categorizar(
        descricao,
        regrasAprendidasNormalizadas,
      );
      categoriasPorFonte[categoriaResolvida.fonte] =
          (categoriasPorFonte[categoriaResolvida.fonte] ?? 0) + 1;

      final dataCompetencia = _calcularDataCompetenciaFatura(
        dataCompra ?? dataLancamento,
        cartao.diaFechamento,
      );
      final dataBase = dataCompra ?? dataLancamento;
      final hash = _hashImportacao(
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
    final resultado = <String, List<SugestaoVinculoRecebimento>>{};

    for (final recebimento in recebimentos) {
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
    final sugestoes = <SugestaoVinculoRecebimento>[];
    final nomeDetectado = _normalizarTextoBusca(
      recebimento.nomeExtraido ?? '',
    );

    for (final conta in contasPendentes) {
      if (conta.foiPago) {
        continue;
      }

      final nomeConta = _normalizarTextoBusca(conta.nome);
      final descricaoConta = _normalizarTextoBusca(conta.descricao);
      final nomeScore = nomeDetectado.isEmpty
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

      final diferenca = (conta.valor.abs() - recebimento.valor.abs()).abs();
      final double toleranciaValor = max(5, recebimento.valor.abs() * 0.15);
      final valorCompativel = diferenca <= toleranciaValor;
      final valorScore = (1 - (diferenca / max(recebimento.valor.abs(), 1)))
          .clamp(0, 1);
      final score = nomeDetectado.isEmpty
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
    final regrasJaAprendidas = regrasExistentes
        .map((r) => _normalizarTextoBusca(r.termo))
        .where((termo) => termo.isNotEmpty)
        .toSet();

    final termoOriginalPorChave = <String, String>{};
    final ocorrenciasPorChave = <String, int>{};
    final votosPorChave = <String, Map<CategoriaGasto, int>>{};

    for (final gasto in gastos) {
      if (gasto.categoria == CategoriaGasto.outros) {
        continue;
      }

      final termoOriginal = gasto.titulo.trim();
      final chave = _normalizarTextoBusca(termoOriginal);
      if (chave.isEmpty ||
          chave.length < 3 ||
          regrasJaAprendidas.contains(chave)) {
        continue;
      }

      termoOriginalPorChave.putIfAbsent(chave, () => termoOriginal);
      ocorrenciasPorChave[chave] = (ocorrenciasPorChave[chave] ?? 0) + 1;
      final votos = votosPorChave.putIfAbsent(
        chave,
        () => <CategoriaGasto, int>{},
      );
      votos[gasto.categoria] = (votos[gasto.categoria] ?? 0) + 1;
    }

    final sugestoes = <SugestaoRegraCategoria>[];
    for (final entry in ocorrenciasPorChave.entries) {
      if (entry.value < minimoOcorrencias) {
        continue;
      }

      final votos = votosPorChave[entry.key] ?? const <CategoriaGasto, int>{};
      if (votos.isEmpty) {
        continue;
      }

      final ranking = votos.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final vencedor = ranking.first;

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
    final qtdPontoVirgula = ';'.allMatches(linha).length;
    final qtdVirgula = ','.allMatches(linha).length;
    return qtdPontoVirgula >= qtdVirgula ? ';' : ',';
  }

  List<String> _parseLinhaCsv(String linha, String separador) {
    final valores = <String>[];
    final atual = StringBuffer();
    var entreAspas = false;

    for (var i = 0; i < linha.length; i++) {
      final char = linha[i];

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
    final v = valor.trim();
    if (v.isEmpty) {
      return null;
    }

    final iso = DateTime.tryParse(v);
    if (iso != null) {
      return iso;
    }

    final Match? br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(v);
    if (br != null) {
      final dia = int.parse(br.group(1)!);
      final mes = int.parse(br.group(2)!);
      final ano = int.parse(br.group(3)!);
      return DateTime(ano, mes, dia);
    }

    final Match? brCurto = RegExp(r'^(\d{2})/(\d{2})/(\d{2})$').firstMatch(v);
    if (brCurto != null) {
      final dia = int.parse(brCurto.group(1)!);
      final mes = int.parse(brCurto.group(2)!);
      final ano = 2000 + int.parse(brCurto.group(3)!);
      return DateTime(ano, mes, dia);
    }

    return null;
  }

  double? _parseValor(String valor) {
    final limpo = valor.trim();
    if (limpo.isEmpty) {
      return null;
    }

    final bruto = limpo
        .replaceAll(RegExp(r'R\$'), '')
        .replaceAll(' ', '')
        .replaceAll(RegExp('[^0-9,.-]'), '');

    if (bruto.isEmpty) {
      return null;
    }

    final ultimoPonto = bruto.lastIndexOf('.');
    final ultimaVirgula = bruto.lastIndexOf(',');

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

    final valorDireto = double.tryParse(normalizado);
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

    final atual = int.tryParse(match.group(1)!);
    final total = int.tryParse(match.group(2)!);

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
    final d = descricao.toUpperCase();
    return d.contains('ESTORNO') ||
        d.contains('CHARGEBACK') ||
        d.contains('AJUSTE') ||
        d.contains('REVERSAO');
  }

  DateTime _calcularDataCompetenciaFatura(DateTime data, int diaFechamento) {
    if (data.day <= diaFechamento) {
      return DateTime(data.year, data.month, data.day);
    }

    var anoCompetencia = data.year;
    var mesCompetencia = data.month + 1;
    if (mesCompetencia > DateTime.december) {
      mesCompetencia = DateTime.january;
      anoCompetencia++;
    }

    final ultimoDiaMesCompetencia = DateTime(
      anoCompetencia,
      mesCompetencia + 1,
      0,
    ).day;
    final diaCompetencia = data.day <= ultimoDiaMesCompetencia
        ? data.day
        : ultimoDiaMesCompetencia;

    return DateTime(anoCompetencia, mesCompetencia, diaCompetencia);
  }

  TipoRecebimentoDetectado _classificarRecebimento(String descricao) {
    final d = _normalizarTextoBusca(descricao).toUpperCase();

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

  // bool _ehPossivelRecebimento(String descricao) {
  //   final TipoRecebimentoDetectado tipo = _classificarRecebimento(descricao);
  //   if (tipo != TipoRecebimentoDetectado.outro) {
  //     return true;
  //   }

  //   final String d = _normalizarTextoBusca(descricao).toUpperCase();
  //   return d.contains('RECEBIDO') ||
  //       d.contains('RECEBIMENTO') ||
  //       d.contains('CREDITO RECEBIDO') ||
  //       d.contains('DEPOSITO RECEBIDO');
  // }

  String? _extrairNomeContraparte(String descricao) {
    final partes = descricao.split('-');
    if (partes.length < 2) {
      return null;
    }

    final candidata = partes.sublist(1).join(' ').trim();
    if (candidata.isEmpty) {
      return null;
    }

    final Match? match = RegExp(
      r'([A-Za-zÀ-ÿ]{2,}(?:\s+[A-Za-zÀ-ÿ]{2,}){0,5})',
    ).firstMatch(candidata);
    if (match == null) {
      return null;
    }

    final nome = _normalizarTextoBusca(match.group(1) ?? '');
    return nome.isEmpty ? null : nome;
  }

  String _normalizarTextoBusca(String texto) =>
      TextNormalizer.normalizeForSearch(texto);

  CategoriaResolvida _categorizar(
    String descricao,
    List<_RegraAprendidaNormalizada> regrasAprendidas,
  ) {
    final d = _normalizarTextoBusca(descricao);
    final tokensDescricao = _tokensRelevantes(d);

    for (final regra in regrasAprendidas) {
      if (d.contains(regra.termoNormalizado)) {
        return CategoriaResolvida(
          categoria: regra.categoria,
          fonte: 'historico_exato',
        );
      }
    }

    double melhorScore = 0;
    CategoriaGasto? melhorCategoria;
    for (final regra in regrasAprendidas) {
      final tokensRegra = regra.tokens;
      if (tokensRegra.isEmpty || tokensDescricao.isEmpty) {
        continue;
      }

      final score = _jaccard(tokensDescricao, tokensRegra);
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

    for (final entry in _regrasPadraoNormalizadas) {
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

    final inter = a.intersection(b);
    final uniao = a.union(b);
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
    final base =
        '$cartaoId|${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}|${descricao.trim().toUpperCase()}|${valor.toStringAsFixed(2)}';
    return _fnv1a64(base);
  }

  String _fnv1a64(String value) {
    final offset = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask64 = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);

    var hash = offset;
    for (final byte in value.codeUnits) {
      hash ^= BigInt.from(byte);
      hash = (hash * prime) & mask64;
    }

    final hex = hash.toRadixString(16);
    return hex.padLeft(max(16, hex.length), '0');
  }
}
