class CartaoCredito {
  final String id;
  final String nome;
  final String finalCartao;
  final int diaFechamento;
  final int diaVencimento;

  const CartaoCredito({
    required this.id,
    required this.nome,
    required this.finalCartao,
    required this.diaFechamento,
    required this.diaVencimento,
  });

  factory CartaoCredito.fromMap(Map<String, dynamic> map, String id) {
    return CartaoCredito(
      id: id,
      nome: (map['nome'] ?? '').toString(),
      finalCartao: (map['finalCartao'] ?? '').toString(),
      diaFechamento: _parseDia(map['diaFechamento']),
      diaVencimento: _parseDia(map['diaVencimento']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'finalCartao': finalCartao,
      'diaFechamento': diaFechamento,
      'diaVencimento': diaVencimento,
    };
  }

  CartaoCredito copyWith({
    String? id,
    String? nome,
    String? finalCartao,
    int? diaFechamento,
    int? diaVencimento,
  }) {
    return CartaoCredito(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      finalCartao: finalCartao ?? this.finalCartao,
      diaFechamento: diaFechamento ?? this.diaFechamento,
      diaVencimento: diaVencimento ?? this.diaVencimento,
    );
  }

  String get label => '$nome •••• $finalCartao';

  static int _parseDia(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 1;
  }
}

