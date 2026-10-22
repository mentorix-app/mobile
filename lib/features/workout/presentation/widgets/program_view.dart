import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/widgets/app_back_button.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/adaptive_refresh_scroll_view.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_day.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/usecases/find_next_workout_day.dart';
import 'package:mentorix_app/features/workout/presentation/localized_name.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_card.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_header.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/rest_day_card.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/week_heading.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/week_selector.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Назначенная программа: крупное название (сворачивается при прокрутке), под ним
/// тренер и прогресс, выбор недели и дни выбранной недели. Левый край всего
/// содержимого один — `AppSpacing.lg`.
///
/// Пока пользователь неделю не выбрал, показывается стартовая — первая с
/// невыполненным тренировочным днём (если все выполнены — последняя). Выбор
/// хранится здесь и переживает обновление данных; если выбранной недели больше
/// нет (программу поменяли), возвращается стартовая.
class ProgramView extends StatefulWidget {
  const ProgramView({super.key, required this.data, required this.onRefresh});

  final TrainerProgram data;
  final Future<void> Function() onRefresh;

  @override
  State<ProgramView> createState() => _ProgramViewState();
}

class _ProgramViewState extends State<ProgramView> {
  final _selectedWeek = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _selectedWeek.dispose();
    super.dispose();
  }

  /// Неделя, которая сейчас на экране.
  int? _effectiveWeek(int? chosen) {
    final weeks = widget.data.weeks;
    if (weeks.isEmpty) return null;
    if (chosen != null && weeks.any((w) => w.weekNumber == chosen)) {
      return chosen;
    }

    final next = const FindNextWorkoutDay()(widget.data);
    if (next != null) return next.weekNumber;
    return widget.data.isFinished ? weeks.last.weekNumber : weeks.first.weekNumber;
  }

  void _openDay(BuildContext context, ProgramDay day) => context.push(
    RouteNames.workoutDayPath(widget.data.trainerId, day.dayKey),
  );

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final next = const FindNextWorkoutDay()(data);
    final l10n = AppLocalizations.of(context);
    final title = localizedName(
      name: data.program!.name,
      nameRu: data.program!.nameRu,
      localeName: l10n.localeName,
    );

    return ValueListenableBuilder<int?>(
      valueListenable: _selectedWeek,
      builder: (context, chosen, _) {
        final current = _effectiveWeek(chosen);
        final days = <ProgramDay>[
          for (final week in data.weeks)
            if (week.weekNumber == current) ...week.days,
        ];

        return AdaptiveRefreshScrollView(
          onRefresh: widget.onRefresh,
          // Индикатор Android опускается под закреплённую шапку.
          edgeOffset: LargeTitleSliverAppBar.collapsedExtent(context),
          headerSlivers: [
            LargeTitleSliverAppBar(
              title: title.isEmpty ? l10n.programTitle : title,
              leading: const AppBackButton(),
            ),
          ],
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: ProgramHeader(
                  data: data,
                  next: next,
                  onContinue: next == null || next.day.dayKey.isEmpty
                      ? null
                      : () => _openDay(context, next.day),
                ),
              ),
            ),
            if (data.weeks.length > 1)
              SliverToBoxAdapter(
                child: WeekSelector(
                  weekNumbers: [for (final w in data.weeks) w.weekNumber],
                  selected: current,
                  onSelected: (number) => _selectedWeek.value = number,
                ),
              )
            else if (current != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(child: WeekHeading(weekNumber: current)),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList.separated(
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final key = ValueKey('$current/${day.dayKey}/${day.dayNumber}');

                  return day.isRest
                      ? RestDayCard(key: key, dayNumber: day.dayNumber)
                      : DayCard(
                          key: key,
                          day: day,
                          completed: data.isCompleted(day),
                          // Без ключа день не открыть: адрес строится по `day_key`.
                          onTap: day.dayKey.isEmpty
                              ? null
                              : () => _openDay(context, day),
                        );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
