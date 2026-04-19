import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/features/perfil/domain/models/perfil_usuario.dart';

class PerfilSyncException implements Exception {
  const PerfilSyncException(this.message, {this.originalError});

  final String message;
  final Object? originalError;

  @override
  String toString() => message;
}

class PerfilService {
  PerfilService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get usuarioAtual => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _perfilRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<PerfilUsuario?> perfilUsuarioStream(String uid) {
    return _perfilRef(uid).snapshots().map((snapshot) {
      final user = _auth.currentUser;

      if (user == null || user.uid != uid) {
        return null;
      }

      return PerfilUsuario.fromSources(user: user, data: snapshot.data());
    });
  }

  Future<void> garantirDocumentoPerfil({required User user}) async {
    final ref = _perfilRef(user.uid);
    final snapshot = await ref.get();

    final baseData = <String, dynamic>{
      'uid': user.uid,
      'workspaceId': user.uid,
      if ((user.email ?? '').trim().isNotEmpty) 'email': user.email!.trim(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      await ref.set(<String, dynamic>{
        ...baseData,
        if ((user.displayName ?? '').trim().isNotEmpty)
          'nome': user.displayName!.trim(),
        'preferencias': PerfilUsuario.preferenciasIniciais(),
        'displayNameSyncPending': false,
        'criadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return;
    }

    await ref.set(baseData, SetOptions(merge: true));
  }

  Future<void> atualizarNomeExibicao({
    required String uid,
    required String nome,
    String? email,
  }) async {
    final user = _requireAuthenticatedUser(uid);
    await garantirDocumentoPerfil(user: user);

    final nomeTrim = nome.trim();
    if (nomeTrim.length < 2) {
      throw ArgumentError('Informe um nome com ao menos 2 letras.');
    }

    await _perfilRef(uid).set(<String, dynamic>{
      'nome': nomeTrim,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'workspaceId': uid,
      'displayNameSyncPending': true,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await user.updateDisplayName(nomeTrim);
      await user.reload();

      await _perfilRef(uid).set(<String, dynamic>{
        'displayNameSyncPending': false,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      await _perfilRef(uid).set(<String, dynamic>{
        'displayNameSyncPending': true,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      throw PerfilSyncException(
        'Nome salvo no app, mas não foi possível sincronizar com a autenticação. Você pode tentar novamente mais tarde.',
        originalError: e,
      );
    }
  }

  Future<void> sincronizarNomeAuthComPerfil({required String uid}) async {
    final user = _requireAuthenticatedUser(uid);

    final snapshot = await _perfilRef(
      uid,
    ).get();

    final data = snapshot.data() ?? <String, dynamic>{};

    final nomePerfil = (data['nome'] ?? '').toString().trim();
    final nomeAuth = (user.displayName ?? '').trim();
    final syncPendente = data['displayNameSyncPending'] == true;

    if (nomePerfil.isEmpty) {
      if (nomeAuth.isNotEmpty) {
        await _perfilRef(uid).set(<String, dynamic>{
          'nome': nomeAuth,
          'displayNameSyncPending': false,
          'atualizadoEm': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return;
    }

    if (!syncPendente && nomePerfil == nomeAuth) {
      return;
    }

    try {
      await user.updateDisplayName(nomePerfil);
      await user.reload();

      await _perfilRef(uid).set(<String, dynamic>{
        'displayNameSyncPending': false,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      await _perfilRef(uid).set(<String, dynamic>{
        'displayNameSyncPending': true,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      throw PerfilSyncException(
        'Ainda não foi possível sincronizar o nome com a autenticação.',
        originalError: e,
      );
    }
  }

  Future<void> atualizarPreferenciaMostrarValoresDashboard({
    required String uid,
    required bool value,
  }) async {
    final user = _requireAuthenticatedUser(uid);
    await garantirDocumentoPerfil(user: user);

    await _perfilRef(uid).set(<String, dynamic>{
      'preferencias': <String, dynamic>{'mostrarValoresDashboard': value},
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> atualizarPreferenciaConfirmarAcoesDestrutivas({
    required String uid,
    required bool value,
  }) async {
    final user = _requireAuthenticatedUser(uid);
    await garantirDocumentoPerfil(user: user);

    await _perfilRef(uid).set(<String, dynamic>{
      'preferencias': <String, dynamic>{'confirmarAcoesDestrutivas': value},
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> atualizarPreferenciaReceberResumoMensal({
    required String uid,
    required bool value,
  }) async {
    final user = _requireAuthenticatedUser(uid);
    await garantirDocumentoPerfil(user: user);

    await _perfilRef(uid).set(<String, dynamic>{
      'preferencias': <String, dynamic>{'receberResumoMensal': value},
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> atualizarPreferenciaTema({
    required String uid,
    required AppThemePreference value,
  }) async {
    final user = _requireAuthenticatedUser(uid);
    await garantirDocumentoPerfil(user: user);

    await _perfilRef(uid).set(<String, dynamic>{
      'preferencias': <String, dynamic>{'tema': value.value},
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sair() {
    return _auth.signOut();
  }

  User _requireAuthenticatedUser(String uid) {
    final user = _auth.currentUser;

    if (user == null || user.uid != uid) {
      throw StateError('Usuário não autenticado.');
    }

    return user;
  }
}
