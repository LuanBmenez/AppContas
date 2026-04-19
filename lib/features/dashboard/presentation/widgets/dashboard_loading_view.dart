import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';

class DashboardLoadingView extends StatelessWidget {
  const DashboardLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeletonBox(height: 28, width: 220),
          SizedBox(height: AppSpacing.s8),
          AppSkeletonBox(height: 18, width: 180),
          SizedBox(height: AppSpacing.s20),
          AppSkeletonBox(height: 210, radius: 30),
          SizedBox(height: AppSpacing.s16),
          AppSkeletonBox(height: 44, radius: 999),
          SizedBox(height: AppSpacing.s16),
          AppSkeletonBox(height: 64, radius: 22),
        ],
      ),
    );
  }
}
