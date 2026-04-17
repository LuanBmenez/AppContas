import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class DashboardEntry extends StatelessWidget {
  const DashboardEntry({
    super.key,
    required this.child,
    required this.delayMs,
  });

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final bool reduzirAnimacoes =
        (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);

    if (reduzirAnimacoes) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: AppMotion.fast.inMilliseconds + delayMs),
      curve: AppMotion.curve,
      builder: (context, value, _) {
        final double slide = (1 - value) * 0.04;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * slide),
            child: child,
          ),
        );
      },
    );
  }
}
