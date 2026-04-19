import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:paga_o_que_me_deve/core/theme/app_theme_preference.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _authSubscription = _auth.authStateChanges().listen(_onAuthChanged);
    _onAuthChanged(_auth.currentUser);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _perfilSubscription;

  ThemeMode _themeMode = ThemeMode.system;
  AppThemePreference _preference = AppThemePreference.system;

  ThemeMode get themeMode => _themeMode;
  AppThemePreference get preference => _preference;

  void _onAuthChanged(User? user) {
    _perfilSubscription?.cancel();
    _perfilSubscription = null;

    if (user == null) {
      _setPreference(AppThemePreference.system);
      return;
    }

    _perfilSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          final data =
              snapshot.data() ?? <String, dynamic>{};
          final preferencias =
              (data['preferencias'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

          _setPreference(AppThemePreference.fromValue(preferencias['tema']));
        });
  }

  void _setPreference(AppThemePreference preference) {
    final nextMode = preference.themeMode;
    final changed = preference != _preference || nextMode != _themeMode;

    _preference = preference;
    _themeMode = nextMode;

    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _perfilSubscription?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }
}
