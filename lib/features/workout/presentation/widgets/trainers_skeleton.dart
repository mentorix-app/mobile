import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/skeleton_box.dart';

/// Скелетон списка тренеров: три карточки высотой с настоящую. Не прокручивается
/// и не обновляется: пока идёт первая загрузка, тянуть нечего.
class TrainersSkeleton extends StatelessWidget {
  const TrainersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, _) =>
                const SkeletonBox(height: 66, radius: AppRadii.xl),
          ),
        ),
      ],
    );
  }
}
