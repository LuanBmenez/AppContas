import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../models/conta_model.dart';
import '../models/gasto_model.dart';

class DashboardResumo {
  final List<Gasto> gastos;
  final List<Conta> contas;

  const DashboardResumo(this.gastos, this.contas);
}

class DatabaseService {
  final CollectionReference<Map<String, dynamic>> _receberCollection =
      FirebaseFirestore.instance.collection('a_receber');
  final CollectionReference<Map<String, dynamic>> _gastosCollection =
      FirebaseFirestore.instance.collection('meus_gastos');

  Future<void> adicionarRecebivel(Conta conta) async {
    final DocumentReference<Map<String, dynamic>> docRef = _receberCollection
        .doc();
    final Conta contaComId = conta.copyWith(id: docRef.id);

    await docRef.set(contaComId.toMap());
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
    await _receberCollection.doc(id).update({'foiPago': !statusAtual});
  }

  Future<void> deletarRecebivel(String id) async {
    await _receberCollection.doc(id).delete();
  }

  Future<void> adicionarGasto(Gasto gasto) async {
    final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
        .doc();
    final Gasto gastoComId = gasto.copyWith(id: docRef.id);

    await docRef.set(gastoComId.toMap());
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

  Stream<DashboardResumo> get dashboardResumo {
    return Rx.combineLatest2<List<Gasto>, List<Conta>, DashboardResumo>(
      meusGastos,
      contasAReceber,
      (gastos, contas) => DashboardResumo(gastos, contas),
    );
  }

  Future<void> deletarGasto(String id) async {
    await _gastosCollection.doc(id).delete();
  }
}
