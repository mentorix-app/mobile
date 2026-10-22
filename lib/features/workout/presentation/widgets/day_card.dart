import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_day.dart';
import 'package:mentorix_app/features/workout/presentation/block_type_label.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Тренировочный день в списке недели: «День N», число упражнений, типы групповых
/// блоков (у `single` подписи нет) и отметка «Выполнено» — нейтральная галочка,
/// подпись рядом, чтобы смысл не держался на значке. [completed] приходит из
/// `completed_days` сервера. [onTap] `null` — карточка не нажимается.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.day,
    required this.completed,
    this.onTap,
  });

  final ProgramDay day;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final textTheme = Theme.of(context).textTheme;

    final details = [
      l10n.programDayExercises(day.exerciseCount),
      for (final type in day.groupTypes) type.label(l10n),
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.dayLabel(day.dayNumber), style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        details,
                        style: textTheme.bodySmall?.copyWith(
                          color: tokens.mutedForeground,
                        ),
                      ),
                      if (completed) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: tokens.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                l10n.dayCompleted,
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: tokens.mutedForeground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
