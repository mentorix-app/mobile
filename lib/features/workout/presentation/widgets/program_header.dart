import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/usecases/find_next_workout_day.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Под крупным названием: тренер, прогресс «N из M» по `completed_days` с
/// сервера и, когда всё выполнено, «Программа пройдена». Прогресса нет, если в
/// программе нет тренировочных дней.
///
/// [onContinue] — кнопка «Продолжить: неделя N, день M» к первому невыполненному
/// тренировочному дню ([next]); `null` — кнопки нет (всё выполнено или у дня нет
/// ключа). Это подсказка, а не замок: дни можно выполнять в любом порядке.
class ProgramHeader extends StatelessWidget {
  const ProgramHeader({
    super.key,
    required this.data,
    this.next,
    this.onContinue,
  });

  final TrainerProgram data;
  final NextWorkoutDay? next;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final textTheme = Theme.of(context).textTheme;

    final trainer = data.trainerName.isEmpty
        ? l10n.trainerDefaultName
        : data.trainerName;
    final total = data.totalTrainingDays;
    final done = data.completedTrainingDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trainer,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(color: tokens.mutedForeground),
        ),
        if (total > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.programProgress(done, total), style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: LinearProgressIndicator(
              value: (done / total).clamp(0, 1).toDouble(),
              minHeight: 6,
            ),
          ),
        ],
        if (next != null && onContinue != null) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: Text(
                l10n.programContinueAction(next!.weekNumber, next!.day.dayNumber),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
        if (data.isFinished) ...[
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: tokens.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(l10n.programFinished, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
