import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PerfilService {
  PerfilService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get usuarioAtual => _auth.currentUser;

  Stream<Map<String, dynamic>?> perfilUsuarioStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  Future<void> atualizarNomeExibicao({
    required String uid,
    required String nome,
    String? email,
  }) async {
    final String nomeTrim = nome.trim();
    await _firestore.collection('users').doc(uid).set({
      'nome': nomeTrim,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'workspaceId': uid,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final User? user = _auth.currentUser;
    if (user != null && user.uid == uid) {
      await user.updateDisplayName(nomeTrim);
    }
  }

  Future<void> sair() {
    return _auth.signOut();
  }
}
