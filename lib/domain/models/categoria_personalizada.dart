import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoriaPersonalizada {
  const CategoriaPersonalizada({
    required this.id,
    required this.nome,
    required this.corValue,
    required this.iconeCodePoint,
    this.favorita = false,
    this.arquivada = false,
    this.usoCount = 0,
    this.criadaEm,
    this.atualizadaEm,
  });

  factory CategoriaPersonalizada.fromMap(Map<String, dynamic> map, String id) {
    return CategoriaPersonalizada(
      id: id,
      nome: (map['nome'] ?? '').toString().trim(),
      corValue: (map['corValue'] as num?)?.toInt() ?? Colors.blue.toARGB32(),
      iconeCodePoint:
          (map['iconeCodePoint'] as num?)?.toInt() ?? Icons.label.codePoint,
      favorita: map['favorita'] == true,
      arquivada: map['arquivada'] == true,
      usoCount: (map['usoCount'] as num?)?.toInt() ?? 0,
      criadaEm: _parseDate(map['criadaEm']),
      atualizadaEm: _parseDate(map['atualizadaEm']),
    );
  }
  final String id;
  final String nome;
  final int corValue;
  final int iconeCodePoint;
  final bool favorita;
  final bool arquivada;
  final int usoCount;
  final DateTime? criadaEm;
  final DateTime? atualizadaEm;

  Color get cor => Color(corValue);

  IconData get icone => IconData(iconeCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'corValue': corValue,
      'iconeCodePoint': iconeCodePoint,
      'favorita': favorita,
      'arquivada': arquivada,
      'usoCount': usoCount,
      'criadaEm': criadaEm,
      'atualizadaEm': atualizadaEm,
    };
  }

  CategoriaPersonalizada copyWith({
    String? id,
    String? nome,
    int? corValue,
    int? iconeCodePoint,
    bool? favorita,
    bool? arquivada,
    int? usoCount,
    DateTime? criadaEm,
    DateTime? atualizadaEm,
  }) {
    return CategoriaPersonalizada(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      corValue: corValue ?? this.corValue,
      iconeCodePoint: iconeCodePoint ?? this.iconeCodePoint,
      favorita: favorita ?? this.favorita,
      arquivada: arquivada ?? this.arquivada,
      usoCount: usoCount ?? this.usoCount,
      criadaEm: criadaEm ?? this.criadaEm,
      atualizadaEm: atualizadaEm ?? this.atualizadaEm,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
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
    return null;
  }
}
