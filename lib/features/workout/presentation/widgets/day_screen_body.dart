import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_complete_bar.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/rest_day_view.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Найденный день: тренировка ([DayView]) или день отдыха ([RestDayView]).
///
/// «Отметить выполненной» есть, только когда день можно отметить (у назначения есть
/// все идентификаторы, у дня — ключ и упражнения) и он ещё не выполнен по
/// `completed_days` сервера. Панель — `Scaffold.bottomNavigationBar`: нижний отступ
/// экрана берёт на себя она.
class DayScreenBody extends StatelessWidget {
  const DayScreenBody({
    super.key,
    required this.trainerId,
    required this.dayKey,
    required this.located,
    required this.data,
    required this.onRefresh,
  });

  final String trainerId;
  final String dayKey;
  final LocatedDay located;
  final TrainerProgram data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final day = located.day;
    final title = l10n.workoutDayTitle(located.weekNumber, day.dayNumber);
    final completed = data.isCompleted(day);
    final canComplete = !completed && data.completionTargetFor(dayKey) != null;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: day.isRest
            ? RestDayView(
                title: title,
                trainerId: trainerId,
                onRefresh: onRefresh,
              )
            : DayView(
                title: title,
                trainerId: trainerId,
                day: day,
                completed: completed,
                onRefresh: onRefresh,
              ),
      ),
      // Закреплена внизу: тело кончается над ней, уведомления встают над ней.
      bottomNavigationBar: canComplete
          ? DayCompleteBar(
              onPressed: () =>
                  context.push(RouteNames.completeDayPath(trainerId, dayKey)),
            )
          : null,
    );
  }
}
