import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'features/home/home_screen.dart';
import 'core/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const PagaOQueMeDeveApp());
}

class PagaOQueMeDeveApp extends StatelessWidget {
  const PagaOQueMeDeveApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paga o que me deve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home ?? const HomeScreen(),
    );
  }
}
