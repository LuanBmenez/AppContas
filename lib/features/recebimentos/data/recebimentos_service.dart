import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:paga_o_que_me_deve/domain/models/recebimento.dart';
import 'package:paga_o_que_me_deve/domain/repositories/recebimentos_repository.dart';

class RecebimentosService implements RecebimentosRepository {

  RecebimentosService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  String get _uid {
    final user = auth.currentUser;
    if (user == null) throw StateError('Usuário não autenticado');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _recebimentosCollection =>
      firestore.collection('workspaces').doc(_uid).collection('recebimentos');

  @override
  Stream<List<Recebimento>> streamRecebimentosPorMes(String competenciaMes) {
    return _recebimentosCollection
        .where('competenciaMes', isEqualTo: competenciaMes)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recebimento.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<void> salvarRecebimento(Recebimento recebimento) async {
    final data = recebimento.toMap();
    if (recebimento.id.isEmpty) {
      await _recebimentosCollection.add(data);
    } else {
      await _recebimentosCollection.doc(recebimento.id).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> deletarRecebimento(String id) async {
    await _recebimentosCollection.doc(id).delete();
  }

  /// Para migração: retorna todos os recebimentos sem competenciaMes
  Stream<List<Recebimento>> streamRecebimentosSemCompetencia() {
    return _recebimentosCollection
        .where('competenciaMes', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recebimento.fromMap(doc.data(), doc.id))
            .toList());
  }
}
