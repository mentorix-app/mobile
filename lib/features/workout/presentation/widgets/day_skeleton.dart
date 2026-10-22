import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/skeleton_box.dart';

/// Скелетон дня: упражнение без группы и карточка блока. Не прокручивается.
class DaySkeleton extends StatelessWidget {
  const DaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.list(
            children: const [
              SkeletonBox(width: 200, height: 18),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 90, height: 24),
              SizedBox(height: AppSpacing.xl),
              SkeletonBox(height: 190, radius: AppRadii.xl),
              SizedBox(height: AppSpacing.xl),
              SkeletonBox(width: 160, height: 18),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 110, height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
