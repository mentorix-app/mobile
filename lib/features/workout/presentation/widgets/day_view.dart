import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/adaptive_refresh_scroll_view.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_day.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/block_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/completed_status.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_app_bar.dart';

/// Содержимое тренировочного дня: блоки по порядку и, если день уже выполнен
/// (по `completed_days` сервера), «Выполнено» в конце. Обновляется свайпом вниз.
/// Кнопка «Отметить выполненной» закреплена снизу самим экраном (`DayScreenBody`).
class DayView extends StatelessWidget {
  const DayView({
    super.key,
    required this.title,
    required this.trainerId,
    required this.day,
    required this.completed,
    required this.onRefresh,
  });

  /// «Неделя N, день M».
  final String title;
  final String trainerId;
  final ProgramDay day;
  final bool completed;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdaptiveRefreshScrollView(
      onRefresh: onRefresh,
      edgeOffset: LargeTitleSliverAppBar.collapsedExtent(context),
      headerSlivers: [DayAppBar(title: title, trainerId: trainerId)],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          sliver: SliverList.separated(
            itemCount: day.blocks.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
            itemBuilder: (context, index) {
              final block = day.blocks[index];

              return BlockView(
                key: ValueKey('${block.id}/$index'),
                block: block,
              );
            },
          ),
        ),
        if (completed)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(child: CompletedStatus()),
          ),
      ],
    );
  }
}
