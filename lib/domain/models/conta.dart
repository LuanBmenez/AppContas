import 'package:cloud_firestore/cloud_firestore.dart';

enum ContaHistoricoTipo { criada, atualizada, recebida, reaberta }

class ContaHistoricoEvento {

  const ContaHistoricoEvento({
    required this.tipo,
    required this.descricao,
    required this.data,
  });

  factory ContaHistoricoEvento.fromMap(Map<String, dynamic> map) {
    return ContaHistoricoEvento(
      tipo: _parseTipo(map['tipo']),
      descricao: (map['descricao'] ?? '').toString(),
      data: _parseDate(map['data']),
    );
  }
  final ContaHistoricoTipo tipo;
  final String descricao;
  final DateTime data;

  Map<String, dynamic> toMap() {
    return {'tipo': tipo.name, 'descricao': descricao, 'data': data};
  }

  static ContaHistoricoTipo _parseTipo(dynamic raw) {
    final valor = raw?.toString() ?? '';
    for (final tipo in ContaHistoricoTipo.values) {
      if (tipo.name == valor) {
        return tipo;
      }
    }
    return ContaHistoricoTipo.atualizada;
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }

    if (raw is DateTime) {
      return raw;
    }

    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }

    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return DateTime.now();
  }
}

class Conta {

  Conta({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.valor,
    required this.data,
    this.vencimento,
    this.recebidaEm,
    this.atualizadaEm,
    this.foiPago = false,
    this.historico = const <ContaHistoricoEvento>[],
  });

  factory Conta.fromMap(Map<String, dynamic> map, String id) {
    final dynamic valorRaw = map['valor'];
    final dynamic dataRaw = map['data'];
    final dynamic vencimentoRaw = map['vencimento'];
    final dynamic recebidaEmRaw = map['recebidaEm'];
    final dynamic atualizadaEmRaw = map['atualizadaEm'];
    final historicoRaw =
        map['historico'] as List<dynamic>? ?? <dynamic>[];
    final historico = historicoRaw
        .whereType<Map<String, dynamic>>()
        .map(ContaHistoricoEvento.fromMap)
        .toList();
    final criadaEm = _parseDate(dataRaw);

    return Conta(
      id: id,
      nome: (map['nome'] ?? map['nomeDevedor'] ?? '').toString(),
      descricao: (map['descricao'] ?? map['categoria'] ?? '').toString(),
      valor: valorRaw is num
          ? valorRaw.toDouble()
          : double.tryParse(valorRaw?.toString() ?? '') ?? 0,
      data: criadaEm,
      vencimento: _parseNullableDate(vencimentoRaw),
      recebidaEm: _parseNullableDate(recebidaEmRaw),
      atualizadaEm: _parseNullableDate(atualizadaEmRaw),
      foiPago: map['foiPago'] == true,
      historico: historico.isEmpty
          ? <ContaHistoricoEvento>[
              ContaHistoricoEvento(
                tipo: ContaHistoricoTipo.criada,
                descricao: 'Cobrança criada',
                data: criadaEm,
              ),
            ]
          : historico,
    );
  }
  final String id;
  final String nome;
  final String descricao;
  final double valor;
  final DateTime data;
  final DateTime? vencimento;
  final DateTime? recebidaEm;
  final DateTime? atualizadaEm;
  final bool foiPago;
  final List<ContaHistoricoEvento> historico;

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'valor': valor,
      'data': data,
      'criadaEm': data,
      'vencimento': vencimento,
      'recebidaEm': recebidaEm,
      'atualizadaEm': atualizadaEm,
      'foiPago': foiPago,
      'historico': historico.map((evento) => evento.toMap()).toList(),
    };
  }

  Conta copyWith({
    String? id,
    String? nome,
    String? descricao,
    double? valor,
    DateTime? data,
    DateTime? vencimento,
    DateTime? recebidaEm,
    DateTime? atualizadaEm,
    bool? foiPago,
    List<ContaHistoricoEvento>? historico,
  }) {
    return Conta(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      vencimento: vencimento ?? this.vencimento,
      recebidaEm: recebidaEm ?? this.recebidaEm,
      atualizadaEm: atualizadaEm ?? this.atualizadaEm,
      foiPago: foiPago ?? this.foiPago,
      historico: historico ?? this.historico,
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }

    if (raw is DateTime) {
      return raw;
    }

    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }

    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    throw FormatException('Campo data invalido em Conta: $raw');
  }

  static DateTime? _parseNullableDate(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is Timestamp) {
      return raw.toDate();
    }

    if (raw is DateTime) {
      return raw;
    }

    if (raw is String) {
      return DateTime.tryParse(raw);
    }

    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return null;
  }
}
