import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';
import 'package:mentorix_app/features/workout/presentation/localized_name.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/stats_metric.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Активность с этим тренером за всё время: всего, за 7 и 30 дней, серия недель (пн–вс
/// по UTC). Если программ было больше одной — число отметок по каждой.
class StatsActivityCard extends StatelessWidget {
  const StatsActivityCard({super.key, required this.activity});

  final ClientActivity activity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatsMetric(
                    label: l10n.statsTotal,
                    value: activity.totalCompletions,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatsMetric(
                    label: l10n.statsLast7Days,
                    value: activity.completionsLast7Days,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatsMetric(
                    label: l10n.statsLast30Days,
                    value: activity.completionsLast30Days,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatsMetric(
                    label: l10n.statsWeekStreak,
                    value: activity.weekStreak,
                  ),
                ),
              ],
            ),
            if (activity.byProgram.length > 1) ...[
              const SizedBox(height: AppSpacing.lg),
              for (final program in activity.byProgram)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizedName(
                            name: program.programName,
                            nameRu: program.programNameRu,
                            localeName: l10n.localeName,
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text('${program.totalCompletions}', style: textTheme.bodyMedium),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
