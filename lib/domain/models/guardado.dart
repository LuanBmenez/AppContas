import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum GuardadoDestino {
  caixinha,
  investimentos,
  saldoLivre,
  semDestino,
}

extension GuardadoDestinoX on GuardadoDestino {
  String get label {
    switch (this) {
      case GuardadoDestino.caixinha:
        return 'Caixinha';
      case GuardadoDestino.investimentos:
        return 'Investimentos';
      case GuardadoDestino.saldoLivre:
        return 'Saldo livre';
      case GuardadoDestino.semDestino:
        return 'Sem destino';
    }
  }

  IconData get icon {
    switch (this) {
      case GuardadoDestino.caixinha:
        return Icons.savings_outlined;
      case GuardadoDestino.investimentos:
        return Icons.trending_up_outlined;
      case GuardadoDestino.saldoLivre:
        return Icons.account_balance_wallet_outlined;
      case GuardadoDestino.semDestino:
        return Icons.hourglass_empty_outlined;
    }
  }

  Color get color {
    switch (this) {
      case GuardadoDestino.caixinha:
        return const Color(0xFF0F9D7A);
      case GuardadoDestino.investimentos:
        return const Color(0xFF2563EB);
      case GuardadoDestino.saldoLivre:
        return const Color(0xFF7C3AED);
      case GuardadoDestino.semDestino:
        return const Color(0xFF6B7280);
    }
  }
}

enum GuardadoTipoMovimentacao {
  aporte,
  resgate,
}

extension GuardadoTipoMovimentacaoX on GuardadoTipoMovimentacao {
  String get label {
    switch (this) {
      case GuardadoTipoMovimentacao.aporte:
        return 'Aporte';
      case GuardadoTipoMovimentacao.resgate:
        return 'Resgate';
    }
  }

  String get acaoLabel {
    switch (this) {
      case GuardadoTipoMovimentacao.aporte:
        return 'Guardar';
      case GuardadoTipoMovimentacao.resgate:
        return 'Resgatar';
    }
  }

  IconData get icon {
    switch (this) {
      case GuardadoTipoMovimentacao.aporte:
        return Icons.arrow_downward_rounded;
      case GuardadoTipoMovimentacao.resgate:
        return Icons.arrow_upward_rounded;
    }
  }

  Color get color {
    switch (this) {
      case GuardadoTipoMovimentacao.aporte:
        return const Color(0xFF0F9D7A);
      case GuardadoTipoMovimentacao.resgate:
        return const Color(0xFFC26A00);
    }
  }

  int get fator {
    switch (this) {
      case GuardadoTipoMovimentacao.aporte:
        return 1;
      case GuardadoTipoMovimentacao.resgate:
        return -1;
    }
  }
}

class Guardado {
  const Guardado({
    required this.id,
    required this.valor,
    required this.data,
    required this.competencia,
    required this.destino,
    this.tipoMovimentacao = GuardadoTipoMovimentacao.aporte,
    this.metaNome,
    this.observacao,
  });

  final String id;
  final double valor;
  final DateTime data;
  final String competencia;
  final GuardadoDestino destino;
  final GuardadoTipoMovimentacao tipoMovimentacao;
  final String? metaNome;
  final String? observacao;

  double get valorAssinado => valor * tipoMovimentacao.fator;

  Guardado copyWith({
    String? id,
    double? valor,
    DateTime? data,
    String? competencia,
    GuardadoDestino? destino,
    GuardadoTipoMovimentacao? tipoMovimentacao,
    String? metaNome,
    String? observacao,
  }) {
    return Guardado(
      id: id ?? this.id,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      competencia: competencia ?? this.competencia,
      destino: destino ?? this.destino,
      tipoMovimentacao: tipoMovimentacao ?? this.tipoMovimentacao,
      metaNome: metaNome ?? this.metaNome,
      observacao: observacao ?? this.observacao,
    );
  }

  static String competenciaFromDate(DateTime data) {
    return '${data.year}-${data.month.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    final String? obs = observacao?.trim();
    final String? meta = metaNome?.trim();

    return <String, dynamic>{
      'valor': valor,
      'data': Timestamp.fromDate(data),
      'competencia': competencia,
      'destino': destino.name,
      'tipoMovimentacao': tipoMovimentacao.name,
      'metaNome': (meta == null || meta.isEmpty) ? null : meta,
      'observacao': (obs == null || obs.isEmpty) ? null : obs,
    };
  }

  factory Guardado.fromMap(Map<String, dynamic> map, String id) {
    final dynamic rawData = map['data'];
    DateTime data;

    if (rawData is Timestamp) {
      data = rawData.toDate();
    } else if (rawData is DateTime) {
      data = rawData;
    } else if (rawData is String) {
      data = DateTime.tryParse(rawData) ?? DateTime.now();
    } else {
      data = DateTime.now();
    }

    final String destinoRaw =
        (map['destino'] as String?) ?? GuardadoDestino.semDestino.name;
    final GuardadoDestino destino = GuardadoDestino.values.firstWhere(
      (item) => item.name == destinoRaw,
      orElse: () => GuardadoDestino.semDestino,
    );

    final String tipoRaw =
        (map['tipoMovimentacao'] as String?) ??
        GuardadoTipoMovimentacao.aporte.name;
    final GuardadoTipoMovimentacao tipoMovimentacao =
        GuardadoTipoMovimentacao.values.firstWhere(
          (item) => item.name == tipoRaw,
          orElse: () => GuardadoTipoMovimentacao.aporte,
        );

    final String? observacao = (map['observacao'] as String?)?.trim();
    final String? metaNome = (map['metaNome'] as String?)?.trim();

    return Guardado(
      id: id,
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      data: data,
      competencia:
          (map['competencia'] as String?)?.trim().isNotEmpty == true
              ? (map['competencia'] as String).trim()
              : competenciaFromDate(data),
      destino: destino,
      tipoMovimentacao: tipoMovimentacao,
      metaNome: (metaNome == null || metaNome.isEmpty) ? null : metaNome,
      observacao:
          (observacao == null || observacao.isEmpty) ? null : observacao,
    );
  }
}
