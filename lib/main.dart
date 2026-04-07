import 'dart:developer' as developer;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';

export 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();

  runApp(const PagaOQueMeDeveApp());
}

Future<void> _activateAppCheck() async {
  try {
    if (kIsWeb) {
      const String siteKey = String.fromEnvironment(
        'FIREBASE_RECAPTCHA_SITE_KEY',
      );

      if (siteKey.isEmpty) {
        developer.log(
          'FIREBASE_RECAPTCHA_SITE_KEY ausente. App Check Web nao ativado.',
          name: 'app.bootstrap',
          level: 900,
        );
        return;
      }

      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(siteKey),
      );
      return;
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
  } catch (e, st) {
    developer.log(
      'Falha ao ativar App Check: $e',
      name: 'app.bootstrap',
      level: 1000,
      stackTrace: st,
    );
  }
}
