import 'package:flutter/material.dart';

import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class AppFormSubmitBar extends StatelessWidget {
  const AppFormSubmitBar({
    required this.onPressed, required this.label, super.key,
    this.isLoading = false,
    this.loadingLabel = 'Salvando...',
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.s8),
        child: SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: isLoading ? null : onPressed,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(loadingLabel),
                    ],
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
