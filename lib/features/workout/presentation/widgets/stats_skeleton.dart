import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/skeleton_box.dart';

/// Скелетон статистики: заголовок раздела, карточка и две записи. Не прокручивается.
class StatsSkeleton extends StatelessWidget {
  const StatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.list(
            children: const [
              SkeletonBox(width: 180, height: 20),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(height: 110, radius: AppRadii.xl),
              SizedBox(height: AppSpacing.xl),
              SkeletonBox(width: 200, height: 20),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(width: 150, height: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(height: 56, radius: AppRadii.xl),
              SizedBox(height: AppSpacing.lg),
              SkeletonBox(width: 150, height: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(height: 56, radius: AppRadii.xl),
            ],
          ),
        ),
      ],
    );
  }
}
