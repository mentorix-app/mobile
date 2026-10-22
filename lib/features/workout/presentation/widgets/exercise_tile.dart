import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_exercise.dart';
import 'package:mentorix_app/features/workout/presentation/exercise_volume.dart';
import 'package:mentorix_app/features/workout/presentation/localized_name.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/expandable_text.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/volume_chips.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Упражнение: название (на языке приложения, без названия — «Упражнение»),
/// подходы и повторы, инструкция. Пустые подходы, повторы и инструкция не
/// показываются; длинная инструкция сворачивается. [blockType] нужен, чтобы
/// подписать `sets` правильно (в EMOM это раунды или минуты).
class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    super.key,
    required this.exercise,
    required this.blockType,
  });

  final ProgramExercise exercise;
  final BlockType blockType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    final name = localizedName(
      name: exercise.name,
      nameRu: exercise.nameRu,
      localeName: l10n.localeName,
    );
    final volume = exerciseVolume(l10n, exercise, blockType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? l10n.exerciseDefaultName : name,
          style: textTheme.titleMedium,
        ),
        if (volume.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          VolumeChips(items: volume),
        ],
        if (exercise.instruction.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ExpandableText(text: exercise.instruction),
        ],
      ],
    );
  }
}
