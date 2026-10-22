import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/skeleton_box.dart';

/// Скелетон программы: шапка и три карточки дней. Не прокручивается и не
/// обновляется — пока идёт первая загрузка, тянуть нечего.
class ProgramSkeleton extends StatelessWidget {
  const ProgramSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.list(
            children: const [
              SkeletonBox(width: 220, height: 24),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 120, height: 14),
              SizedBox(height: AppSpacing.lg),
              SkeletonBox(width: 160, height: 14),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(height: 6, radius: AppRadii.sm),
              SizedBox(height: AppSpacing.xl),
              SkeletonBox(height: 72, radius: AppRadii.xl),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(height: 72, radius: AppRadii.xl),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(height: 72, radius: AppRadii.xl),
            ],
          ),
        ),
      ],
    );
  }
}
