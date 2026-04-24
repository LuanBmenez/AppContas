import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusRecebimento { pendente, recebido, atrasado }

class Recebimento {
  Recebimento({
    required this.id,
    required this.valor,
    required this.dataPrevista,
    required this.status,
    required this.competenciaMes,
    this.dataRecebido,
  });

  factory Recebimento.fromMap(Map<String, dynamic> map, String id) {
    // Agora o parse é totalmente seguro contra falhas e nulos!
    final dataPrevista = _parseDate(map['dataPrevista']);
    final dataRecebido = _parseNullableDate(map['dataRecebido']);

    final competenciaMes =
        map['competenciaMes'] as String? ??
        "${dataPrevista.year.toString().padLeft(4, '0')}-${dataPrevista.month.toString().padLeft(2, '0')}";

    StatusRecebimento status;
    if (dataRecebido != null) {
      status = StatusRecebimento.recebido;
    } else if (dataPrevista.isBefore(DateTime.now())) {
      status = StatusRecebimento.atrasado;
    } else {
      status = StatusRecebimento.pendente;
    }

    return Recebimento(
      id: id,
      valor: (map['valor'] as num?)?.toDouble() ?? 0.0,
      dataPrevista: dataPrevista,
      dataRecebido: dataRecebido,
      status: status,
      competenciaMes: competenciaMes,
    );
  }

  final String id;
  final double valor;
  final DateTime dataPrevista;
  final DateTime? dataRecebido;
  final StatusRecebimento status;
  final String competenciaMes;

  Map<String, dynamic> toMap() {
    return {
      'valor': valor,
      'dataPrevista': Timestamp.fromDate(dataPrevista),
      'dataRecebido': dataRecebido != null
          ? Timestamp.fromDate(dataRecebido!)
          : null,
      'competenciaMes': competenciaMes,
    };
  }

  static DateTime _parseDate(dynamic raw) {
    return _parseNullableDate(raw) ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }
}
