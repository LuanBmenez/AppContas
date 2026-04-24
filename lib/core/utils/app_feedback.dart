import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/app_theme.dart'; // Ajuste o path se necessário

class AppFeedback {
  AppFeedback._();

  static void showSuccess(BuildContext context, String message) {
    // Agora usa a cor de sucesso oficial do seu Design System!
    _show(context, message, context.semanticColors.success);
  }

  static void showError(BuildContext context, String message) {
    // Agora usa a cor de erro oficial do seu Design System!
    _show(context, message, context.semanticColors.error);
  }

  static void _show(BuildContext context, String message, Color background) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: background,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
