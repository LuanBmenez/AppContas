import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conta_model.dart';
import '../models/gasto_model.dart';

class DatabaseService {
  final CollectionReference<Map<String, dynamic>> _receberCollection =
      FirebaseFirestore.instance.collection('a_receber');
  final CollectionReference<Map<String, dynamic>> _gastosCollection =
      FirebaseFirestore.instance.collection('meus_gastos');

  Future<void> adicionarRecebivel(Conta conta) async {
    try {
      final DocumentReference<Map<String, dynamic>> docRef = _receberCollection
          .doc();
      final Conta contaComId = conta.copyWith(id: docRef.id);

      await docRef.set(contaComId.toMap());
    } on FirebaseException catch (e) {
      throw Exception('Erro ao adicionar a receber: ${e.message ?? e.code}');
    }
  }

  Stream<List<Conta>> get contasAReceber {
    return _receberCollection.orderBy('data', descending: true).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => Conta.fromMap(doc.data(), doc.id))
            .toList();
      },
    );
  }

  Future<void> alternarStatusRecebivel(String id, bool statusAtual) async {
    try {
      await _receberCollection.doc(id).update({'foiPago': !statusAtual});
    } on FirebaseException catch (e) {
      throw Exception('Erro ao atualizar status: ${e.message ?? e.code}');
    }
  }

  Future<void> deletarRecebivel(String id) async {
    try {
      await _receberCollection.doc(id).delete();
    } on FirebaseException catch (e) {
      throw Exception('Erro ao deletar item a receber: ${e.message ?? e.code}');
    }
  }

  Future<void> adicionarGasto(Gasto gasto) async {
    try {
      final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
          .doc();
      final Gasto gastoComId = gasto.copyWith(id: docRef.id);

      await docRef.set(gastoComId.toMap());
    } on FirebaseException catch (e) {
      throw Exception('Erro ao adicionar gasto: ${e.message ?? e.code}');
    }
  }

  Stream<List<Gasto>> get meusGastos {
    return _gastosCollection.orderBy('data', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => Gasto.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> deletarGasto(String id) async {
    try {
      await _gastosCollection.doc(id).delete();
    } on FirebaseException catch (e) {
      throw Exception('Erro ao deletar gasto: ${e.message ?? e.code}');
    }
  }
}
