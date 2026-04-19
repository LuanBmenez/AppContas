import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class DashboardEntry extends StatelessWidget {
  const DashboardEntry({
    required this.child, required this.delayMs, super.key,
  });

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduzirAnimacoes =
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
        final slide = (1 - value) * 0.04;
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
