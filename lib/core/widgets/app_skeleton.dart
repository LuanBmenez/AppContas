import 'package:flutter/material.dart';

import '../theme/theme.dart';

class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = 12,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.45, end: 0.9),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      onEnd: () {},
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          AppSkeletonBox(height: 28, width: 220),
          SizedBox(height: AppSpacing.s8),
          AppSkeletonBox(height: 18, width: 150),
          SizedBox(height: AppSpacing.s12),
          AppSkeletonBox(height: 32),
          SizedBox(height: AppSpacing.s24),
          AppSkeletonBox(height: 156, radius: 20),
          SizedBox(height: AppSpacing.s12),
          AppSkeletonBox(height: 44, radius: 12),
          SizedBox(height: AppSpacing.s12),
          AppSkeletonBox(height: 44, radius: 12),
        ],
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.withHeader = true});

  final bool withHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        children: [
          if (withHeader) ...const [
            AppSkeletonBox(height: 132, radius: 16),
            SizedBox(height: AppSpacing.s12),
          ],
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) =>
                  const AppSkeletonBox(height: 80, radius: 12),
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.s12),
              itemCount: 4,
            ),
          ),
        ],
      ),
    );
  }
}
