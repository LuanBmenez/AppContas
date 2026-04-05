import 'package:cloud_firestore/cloud_firestore.dart';

class Conta {
  final String id;
  final String nome;
  final String descricao;
  final double valor;
  final DateTime data;
  final bool foiPago;

  Conta({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.valor,
    required this.data,
    this.foiPago = false,
  });

  // Converte um documento do Firebase (JSON) num objeto Conta do Flutter.
  // Mantemos fallback para chaves antigas para facilitar migracao.
  factory Conta.fromMap(Map<String, dynamic> map, String id) {
    final dynamic valorRaw = map['valor'];
    final dynamic dataRaw = map['data'];

    return Conta(
      id: id,
      nome: (map['nome'] ?? map['nomeDevedor'] ?? '').toString(),
      descricao: (map['descricao'] ?? map['categoria'] ?? '').toString(),
      valor: valorRaw is num
          ? valorRaw.toDouble()
          : double.tryParse(valorRaw?.toString() ?? '') ?? 0,
      data: _parseDate(dataRaw),
      foiPago: map['foiPago'] == true,
    );
  }

  // Converte o nosso objeto Conta para um Map que o Firebase consegue guardar.
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'valor': valor,
      'data': data,
      'foiPago': foiPago,
    };
  }

  Conta copyWith({
    String? id,
    String? nome,
    String? descricao,
    double? valor,
    DateTime? data,
    bool? foiPago,
  }) {
    return Conta(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      foiPago: foiPago ?? this.foiPago,
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

    return DateTime.now();
  }
}
