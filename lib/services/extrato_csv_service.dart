import 'dart:math';

import '../models/cartao_credito_model.dart';
import '../models/gasto_model.dart';
import '../models/regra_categoria_importacao_model.dart';
import '../utils/app_formatters.dart';

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
  final int ignorados;
  final Map<String, int> ignoradosPorMotivo;

  const ResultadoMapeamentoExtrato({
    required this.gastos,
    required this.ignorados,
    this.ignoradosPorMotivo = const <String, int>{},
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
        'Galegogaseagua': CategoriaGasto.moradia,
      };

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
    final Map<String, int> ignoradosPorMotivo = <String, int>{};
    final List<RegraCategoriaImportacao> regrasAprendidasOrdenadas =
        List<RegraCategoriaImportacao>.from(regrasAprendidas)
          ..sort((a, b) => b.termo.length.compareTo(a.termo.length));

    void contarIgnorado(String motivo) {
      ignorados++;
      ignoradosPorMotivo[motivo] = (ignoradosPorMotivo[motivo] ?? 0) + 1;
    }

    for (final LinhaExtratoCsv linha in csv.linhas) {
      final String descricao = (linha.colunas[colunaDescricao] ?? '').trim();
      if (descricao.isEmpty) {
        contarIgnorado('Descricao vazia');
        continue;
      }

      final double? valor = _parseValor(linha.colunas[colunaValor] ?? '');
      if (valor == null) {
        contarIgnorado('Valor invalido');
        continue;
      }

      final DateTime? dataLancamento = _parseData(
        linha.colunas[colunaDataLancamento] ?? '',
      );

      if (dataLancamento == null) {
        contarIgnorado('Data de lancamento invalida');
        continue;
      }

      if (_ehPagamentoRecebido(descricao)) {
        contarIgnorado('Pagamento recebido');
        continue;
      }

      final String? colunaDataCompra = mapeamento[CampoExtrato.dataCompra];
      final String? colunaParcela = mapeamento[CampoExtrato.parcela];

      final DateTime? dataCompra = colunaDataCompra == null
          ? null
          : _parseData(linha.colunas[colunaDataCompra] ?? '');

      final String textoParcela = colunaParcela == null
          ? descricao
          : '${linha.colunas[colunaParcela] ?? ''} $descricao';
      final ({int atual, int total})? parcela = _extrairParcela(textoParcela);

      final bool ehEstorno = _ehEstornoOuAjuste(descricao);
      final double valorNormalizado = ehEstorno ? -valor.abs() : valor;
      final CategoriaGasto categoria = _categorizar(
        descricao,
        regrasAprendidasOrdenadas,
      );
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

      gastos.add(
        Gasto(
          id: '',
          titulo: descricao,
          valor: valorNormalizado,
          data: dataCompetencia,
          dataCompra: dataCompra,
          dataLancamento: dataLancamento,
          categoria: categoria,
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
      ignorados: ignorados,
      ignoradosPorMotivo: ignoradosPorMotivo,
    );
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
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^0-9,.-]'), '');

    if (bruto.isEmpty) {
      return null;
    }

    final int ultimoPonto = bruto.lastIndexOf('.');
    final int ultimaVirgula = bruto.lastIndexOf(',');

    // Regra: o ultimo separador encontrado vira decimal; os demais sao milhares.
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
      return DateTime(data.year, data.month, 1);
    }

    if (data.month == DateTime.december) {
      return DateTime(data.year + 1, DateTime.january, 1);
    }

    return DateTime(data.year, data.month + 1, 1);
  }

  bool _ehPagamentoRecebido(String descricao) {
    final String d = _normalizarTextoBusca(descricao);
    if (d.isEmpty) {
      return false;
    }

    const List<String> padroesDiretos = <String>[
      'PAGAMENTO RECEBIDO',
      'PAGTO RECEBIDO',
      'PGTO RECEBIDO',
      'RECEBIMENTO DE PAGAMENTO',
      'PAGAMENTO FATURA RECEBIDO',
    ];

    for (final String padrao in padroesDiretos) {
      if (d.contains(padrao)) {
        return true;
      }
    }

    final bool temPagamento =
        d.contains('PAGAMENTO') || d.contains('PAGTO') || d.contains('PGTO');
    final bool temRecebimento =
        d.contains('RECEBIDO') || d.contains('RECEBIMENTO');

    return temPagamento && temRecebimento;
  }

  String _normalizarTextoBusca(String texto) {
    return texto
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÃÂ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊ]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÕÔ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛ]'), 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  CategoriaGasto _categorizar(
    String descricao,
    List<RegraCategoriaImportacao> regrasAprendidas,
  ) {
    final String d = _normalizarTextoBusca(descricao);

    for (final RegraCategoriaImportacao regra in regrasAprendidas) {
      final String chave = _normalizarTextoBusca(regra.termo);
      if (chave.isNotEmpty && d.contains(chave)) {
        return regra.categoria;
      }
    }

    for (final MapEntry<String, CategoriaGasto> entry
        in _regrasCategoria.entries) {
      final String chave = _normalizarTextoBusca(entry.key);
      if (chave.isNotEmpty && d.contains(chave)) {
        return entry.value;
      }
    }

    return CategoriaGasto.outros;
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
