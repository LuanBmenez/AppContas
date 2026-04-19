import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_configuracao.dart';
import 'package:rxdart/rxdart.dart';

class RecorrenciasConfigService {
  RecorrenciasConfigService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('recorrencias_config');
  }

  Stream<List<RecorrenciaConfiguracao>> streamConfiguracoes() {
    return _auth.authStateChanges().switchMap((user) {
      if (user == null) {
        return Stream.value(const <RecorrenciaConfiguracao>[]);
      }
      return _collection(user.uid).snapshots().map((snapshot) {
        return snapshot.docs.map(RecorrenciaConfiguracao.fromFirestore).toList();
      });
    });
  }

  Future<RecorrenciaConfiguracao?> buscarConfiguracao(String recorrenciaId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _collection(uid).doc(recorrenciaId).get();
    if (!doc.exists) return null;
    return RecorrenciaConfiguracao.fromFirestore(doc);
  }

  Future<void> salvarConfiguracao(RecorrenciaConfiguracao configuracao) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Usuário não autenticado.');
    await _collection(uid).doc(configuracao.recorrenciaId).set(configuracao.toMap(), SetOptions(merge: true));
  }

  Future<void> confirmarRecorrencia(String recorrenciaId, {bool confirmada = true}) async {
    final atual = await buscarConfiguracao(recorrenciaId) ?? RecorrenciaConfiguracao.vazio.copyWith(recorrenciaId: recorrenciaId);
    await salvarConfiguracao(atual.copyWith(confirmada: confirmada, ignorada: false));
  }

  Future<void> pausarRecorrencia(String recorrenciaId, {required bool pausada}) async {
    final atual = await buscarConfiguracao(recorrenciaId) ?? RecorrenciaConfiguracao.vazio.copyWith(recorrenciaId: recorrenciaId);
    await salvarConfiguracao(atual.copyWith(pausada: pausada, ignorada: false));
  }

  Future<void> ignorarRecorrencia(String recorrenciaId, {required bool ignorada}) async {
    final atual = await buscarConfiguracao(recorrenciaId) ?? RecorrenciaConfiguracao.vazio.copyWith(recorrenciaId: recorrenciaId);
    await salvarConfiguracao(atual.copyWith(ignorada: ignorada));
  }

  Future<void> atualizarNotificacao({required String recorrenciaId, required bool ativa, required int diasAntes}) async {
    final atual = await buscarConfiguracao(recorrenciaId) ?? RecorrenciaConfiguracao.vazio.copyWith(recorrenciaId: recorrenciaId);
    await salvarConfiguracao(atual.copyWith(notificacaoAtiva: ativa, diasAntesNotificacao: diasAntes, ignorada: false));
  }
}
