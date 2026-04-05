import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

class Gasto {
  final String id;
  final String titulo;
  final double valor;
  final DateTime data;
  final CategoriaGasto categoria;
  final TipoGasto tipo;

  Gasto({
    required this.id,
    required this.titulo,
    required this.valor,
    required this.data,
    required this.categoria,
    this.tipo = TipoGasto.variavel,
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
      tipo: TipoGasto.values.firstWhere(
        (e) => e.name == map['tipo'],
        orElse: () => TipoGasto.variavel,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'valor': valor,
      'data': data,
      'categoria': categoria.name,
      'tipo': tipo.name,
    };
  }

  Gasto copyWith({
    String? id,
    String? titulo,
    double? valor,
    DateTime? data,
    CategoriaGasto? categoria,
    TipoGasto? tipo,
  }) {
    return Gasto(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      categoria: categoria ?? this.categoria,
      tipo: tipo ?? this.tipo,
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
