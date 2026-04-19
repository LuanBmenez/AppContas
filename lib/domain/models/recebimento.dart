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
    final dataPrevista = (map['dataPrevista'] as Timestamp).toDate();
    final dataRecebido = map['dataRecebido'] != null
        ? (map['dataRecebido'] as Timestamp).toDate()
        : null;

    // Compatibilidade: calcula competencia se não existir
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
      valor: (map['valor'] as num).toDouble(),
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
}
