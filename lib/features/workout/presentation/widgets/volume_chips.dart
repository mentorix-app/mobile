import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/workout/presentation/exercise_volume.dart';

/// Плашки подходов и повторов упражнения. Переносятся на следующую строку, если
/// не помещаются (длинные значения, крупный шрифт).
class VolumeChips extends StatelessWidget {
  const VolumeChips({super.key, required this.items});

  final List<ExerciseVolumeItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeExt;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final item in items)
          Semantics(
            label: item.semantics,
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.muted,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  item.text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: tokens.secondaryForeground,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
