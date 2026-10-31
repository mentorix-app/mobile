import 'package:flutter/material.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/core/widgets/adaptive_refresh_scroll_view.dart';
import 'package:mentorix_app/core/widgets/app_back_button.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/completion_tile.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/stats_activity_card.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/stats_progress_card.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/stats_section_heading.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Статистика: текущая программа, активность и результаты тренировок с ответами
/// тренера. Разделы, которым нечего показывать, пропускаются: нет назначения — нет
/// «Текущей программы», нет отметок — нет «Активности», а в «Результатах» вместо
/// списка пояснение. Обновляется свайпом вниз.
class StatsView extends StatelessWidget {
  const StatsView({
    super.key,
    required this.trainerId,
    required this.data,
    required this.onRefresh,
  });

  final String trainerId;
  final ClientAnalytics data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final assignment = data.currentAssignment;
    final records = data.recentCompletions;
    // Название программы под записью нужно, только когда программ было несколько.
    final showProgramName = data.activity.byProgram.length > 1;

    return AdaptiveRefreshScrollView(
      onRefresh: onRefresh,
      edgeOffset: LargeTitleSliverAppBar.collapsedExtent(context),
      headerSlivers: [
        LargeTitleSliverAppBar(
          title: l10n.statsTitle,
          leading: AppBackButton(
            fallbackLocation: RouteNames.trainerProgramPath(trainerId),
          ),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          sliver: SliverList.list(
            children: [
              if (assignment != null) ...[
                StatsSectionHeading(l10n.statsCurrentProgram),
                const SizedBox(height: AppSpacing.md),
                StatsProgressCard(progress: assignment),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (data.activity.totalCompletions > 0) ...[
                StatsSectionHeading(l10n.statsActivity),
                const SizedBox(height: AppSpacing.md),
                StatsActivityCard(activity: data.activity),
                const SizedBox(height: AppSpacing.xl),
              ],
              StatsSectionHeading(l10n.statsResults),
              const SizedBox(height: AppSpacing.md),
              if (records.isEmpty)
                Text(
                  l10n.statsEmptyResults,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.themeExt.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          sliver: SliverList.separated(
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
            itemBuilder: (context, index) => CompletionTile(
              key: ValueKey(records[index].id),
              record: records[index],
              showProgramName: showProgramName,
            ),
          ),
        ),
      ],
    );
  }
}
