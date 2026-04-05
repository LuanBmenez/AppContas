import 'package:flutter/material.dart';

class AppFeedback {
  AppFeedback._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, const Color(0xFF166534));
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, const Color(0xFFB91C1C));
  }

  static void _show(BuildContext context, String message, Color background) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
