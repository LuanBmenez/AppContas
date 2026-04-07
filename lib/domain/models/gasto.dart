import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/text_normalizer.dart';

enum CategoriaGasto {
  moradia,
  comida,
  transporte,
  entretenimento,
  saude,
  educacao,
  outros,
}

enum TipoGasto { fixo, variavel }

enum OrigemGasto { manual, cartaoCredito }

extension CategoriaGastoInfo on CategoriaGasto {
  String get label {
    switch (this) {
      case CategoriaGasto.moradia:
        return 'Moradia';
      case CategoriaGasto.comida:
        return 'Comida';
      case CategoriaGasto.transporte:
        return 'Transporte';
      case CategoriaGasto.entretenimento:
        return 'Entretenimento';
      case CategoriaGasto.saude:
        return 'Saude';
      case CategoriaGasto.educacao:
        return 'Educacao';
      case CategoriaGasto.outros:
        return 'Outros';
    }
  }

  IconData get icon {
    switch (this) {
      case CategoriaGasto.moradia:
        return Icons.home_outlined;
      case CategoriaGasto.comida:
        return Icons.restaurant_outlined;
      case CategoriaGasto.transporte:
        return Icons.directions_car_outlined;
      case CategoriaGasto.entretenimento:
        return Icons.local_movies_outlined;
      case CategoriaGasto.saude:
        return Icons.favorite_outline;
      case CategoriaGasto.educacao:
        return Icons.menu_book_outlined;
      case CategoriaGasto.outros:
        return Icons.more_horiz;
    }
  }

  Color get color {
    switch (this) {
      case CategoriaGasto.moradia:
        return const Color(0xFF6D4C41);
      case CategoriaGasto.comida:
        return const Color(0xFFE65100);
      case CategoriaGasto.transporte:
        return const Color(0xFF1565C0);
      case CategoriaGasto.entretenimento:
        return const Color(0xFF8E24AA);
      case CategoriaGasto.saude:
        return const Color(0xFFD81B60);
      case CategoriaGasto.educacao:
        return const Color(0xFF2E7D32);
      case CategoriaGasto.outros:
        return const Color(0xFF546E7A);
    }
  }
}

extension TipoGastoInfo on TipoGasto {
  String get label {
    switch (this) {
      case TipoGasto.fixo:
        return 'Fixo';
      case TipoGasto.variavel:
        return 'Variavel';
    }
  }
}

extension OrigemGastoInfo on OrigemGasto {
  String get label {
    switch (this) {
      case OrigemGasto.manual:
        return 'Manual';
      case OrigemGasto.cartaoCredito:
        return 'Cartao de credito';
    }
  }
}

class Gasto {
  final String id;
  final String titulo;
  final double valor;
  final DateTime data;
  final CategoriaGasto categoria;
  final String? categoriaPersonalizadaId;
  final String? categoriaPersonalizadaNome;
  final int? categoriaPersonalizadaCorValue;
  final int? categoriaPersonalizadaIconeCodePoint;
  final TipoGasto tipo;
  final OrigemGasto origem;
  final String? cartaoId;
  final String? cartaoNome;
  final String? hashImportacao;
  final int? parcelaAtual;
  final int? parcelaTotal;
  final DateTime? dataCompra;
  final DateTime? dataLancamento;

  Gasto({
    required this.id,
    required this.titulo,
    required this.valor,
    required this.data,
    required this.categoria,
    this.categoriaPersonalizadaId,
    this.categoriaPersonalizadaNome,
    this.categoriaPersonalizadaCorValue,
    this.categoriaPersonalizadaIconeCodePoint,
    this.tipo = TipoGasto.variavel,
    this.origem = OrigemGasto.manual,
    this.cartaoId,
    this.cartaoNome,
    this.hashImportacao,
    this.parcelaAtual,
    this.parcelaTotal,
    this.dataCompra,
    this.dataLancamento,
  });

  factory Gasto.fromMap(Map<String, dynamic> map, String id) {
    final dynamic valorRaw = map['valor'];
    final dynamic dataRaw = map['data'];

    return Gasto(
      id: id,
      titulo: (map['titulo'] ?? '').toString(),
      valor: valorRaw is num
          ? valorRaw.toDouble()
          : double.tryParse(valorRaw?.toString() ?? '') ?? 0,
      data: _parseDate(dataRaw),
      categoria: CategoriaGasto.values.firstWhere(
        (e) => e.name == map['categoria'],
        orElse: () => CategoriaGasto.outros,
      ),
      categoriaPersonalizadaId: map['categoriaPersonalizadaId']?.toString(),
      categoriaPersonalizadaNome: map['categoriaPersonalizadaNome']?.toString(),
      categoriaPersonalizadaCorValue: _parseNullableInt(
        map['categoriaPersonalizadaCorValue'],
      ),
      categoriaPersonalizadaIconeCodePoint: _parseNullableInt(
        map['categoriaPersonalizadaIconeCodePoint'],
      ),
      tipo: TipoGasto.values.firstWhere(
        (e) => e.name == map['tipo'],
        orElse: () => TipoGasto.variavel,
      ),
      origem: OrigemGasto.values.firstWhere(
        (e) => e.name == map['origem'],
        orElse: () => OrigemGasto.manual,
      ),
      cartaoId: map['cartaoId']?.toString(),
      cartaoNome: map['cartaoNome']?.toString(),
      hashImportacao: map['hashImportacao']?.toString(),
      parcelaAtual: _parseNullableInt(map['parcelaAtual']),
      parcelaTotal: _parseNullableInt(map['parcelaTotal']),
      dataCompra: _parseNullableDate(map['dataCompra']),
      dataLancamento: _parseNullableDate(map['dataLancamento']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'tituloNormalizado': TextNormalizer.normalizeForSearch(titulo),
      'valor': valor,
      'data': data,
      'categoria': categoria.name,
      'categoriaPersonalizadaId': categoriaPersonalizadaId,
      'categoriaPersonalizadaNome': categoriaPersonalizadaNome,
      'categoriaPersonalizadaCorValue': categoriaPersonalizadaCorValue,
      'categoriaPersonalizadaIconeCodePoint':
          categoriaPersonalizadaIconeCodePoint,
      'tipo': tipo.name,
      'origem': origem.name,
      'cartaoId': cartaoId,
      'cartaoNome': cartaoNome,
      'hashImportacao': hashImportacao,
      'parcelaAtual': parcelaAtual,
      'parcelaTotal': parcelaTotal,
      'dataCompra': dataCompra,
      'dataLancamento': dataLancamento,
    };
  }

  Gasto copyWith({
    String? id,
    String? titulo,
    double? valor,
    DateTime? data,
    CategoriaGasto? categoria,
    String? categoriaPersonalizadaId,
    String? categoriaPersonalizadaNome,
    int? categoriaPersonalizadaCorValue,
    int? categoriaPersonalizadaIconeCodePoint,
    TipoGasto? tipo,
    OrigemGasto? origem,
    String? cartaoId,
    String? cartaoNome,
    String? hashImportacao,
    int? parcelaAtual,
    int? parcelaTotal,
    DateTime? dataCompra,
    DateTime? dataLancamento,
  }) {
    return Gasto(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      categoria: categoria ?? this.categoria,
      categoriaPersonalizadaId:
          categoriaPersonalizadaId ?? this.categoriaPersonalizadaId,
      categoriaPersonalizadaNome:
          categoriaPersonalizadaNome ?? this.categoriaPersonalizadaNome,
      categoriaPersonalizadaCorValue:
          categoriaPersonalizadaCorValue ?? this.categoriaPersonalizadaCorValue,
      categoriaPersonalizadaIconeCodePoint:
          categoriaPersonalizadaIconeCodePoint ??
          this.categoriaPersonalizadaIconeCodePoint,
      tipo: tipo ?? this.tipo,
      origem: origem ?? this.origem,
      cartaoId: cartaoId ?? this.cartaoId,
      cartaoNome: cartaoNome ?? this.cartaoNome,
      hashImportacao: hashImportacao ?? this.hashImportacao,
      parcelaAtual: parcelaAtual ?? this.parcelaAtual,
      parcelaTotal: parcelaTotal ?? this.parcelaTotal,
      dataCompra: dataCompra ?? this.dataCompra,
      dataLancamento: dataLancamento ?? this.dataLancamento,
    );
  }

  String? get parcelaLabel {
    if (parcelaAtual == null || parcelaTotal == null) {
      return null;
    }
    return '${parcelaAtual!}/${parcelaTotal!}';
  }

  bool get usaCategoriaPersonalizada {
    return categoriaPersonalizadaId != null &&
        categoriaPersonalizadaNome != null &&
        categoriaPersonalizadaNome!.trim().isNotEmpty;
  }

  String get categoriaLabelExibicao {
    return usaCategoriaPersonalizada
        ? categoriaPersonalizadaNome!.trim()
        : categoria.label;
  }

  Color get categoriaCorExibicao {
    if (usaCategoriaPersonalizada && categoriaPersonalizadaCorValue != null) {
      return Color(categoriaPersonalizadaCorValue!);
    }
    return categoria.color;
  }

  IconData get categoriaIconeExibicao {
    if (usaCategoriaPersonalizada &&
        categoriaPersonalizadaIconeCodePoint != null) {
      return IconData(
        categoriaPersonalizadaIconeCodePoint!,
        fontFamily: 'MaterialIcons',
      );
    }
    return categoria.icon;
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

    throw FormatException('Campo data invalido em Gasto: $raw');
  }

  static DateTime? _parseNullableDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    return _parseDate(raw);
  }

  static int? _parseNullableInt(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is int) {
      return raw;
    }

    if (raw is num) {
      return raw.toInt();
    }

    return int.tryParse(raw.toString());
  }
}
