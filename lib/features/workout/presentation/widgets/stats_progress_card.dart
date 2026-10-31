import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';
import 'package:mentorix_app/features/workout/presentation/completion_time_format.dart';
import 'package:mentorix_app/features/workout/presentation/localized_name.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Текущая программа: название, «Выполнено N из M», процент, полоска и разбивка по
/// неделям (если недель больше одной). Это прогресс текущего цикла.
class StatsProgressCard extends StatelessWidget {
  const StatsProgressCard({super.key, required this.progress});

  final AssignmentProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final textTheme = Theme.of(context).textTheme;
    final name = localizedName(
      name: progress.programName,
      nameRu: progress.programNameRu,
      localeName: l10n.localeName,
    );
    final total = progress.totalTrainingDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name.isNotEmpty) Text(name, style: textTheme.titleMedium),
            if (total > 0) ...[
              if (name.isNotEmpty) const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.programProgress(progress.completedDays, total),
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${formatPercent(progress.completionPercent, l10n.localeName)}%',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: LinearProgressIndicator(
                  value: (progress.completionPercent / 100).clamp(0, 1).toDouble(),
                  minHeight: 6,
                ),
              ),
            ],
            if (progress.weeks.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              for (final week in progress.weeks)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.statsWeekProgress(
                      week.weekNumber,
                      week.completedDays,
                      week.totalDays,
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.mutedForeground,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
