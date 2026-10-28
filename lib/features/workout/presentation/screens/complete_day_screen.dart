import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/widgets/empty_state.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_state.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/complete_day_form.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/completion_scope.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_skeleton.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/no_program_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_frame.dart';
import 'package:mentorix_app/features/workout/presentation/workout_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Ввод результата и отметка дня (`/trainers/:trainerId/days/:dayKey/complete`).
///
/// Форма показывается, только когда программа загружена, назначение есть, день
/// можно отметить и он ещё не выполнен; иначе — загрузка, ошибка или пояснение.
/// Если экран восстановлен системой, программа догружается здесь же.
///
/// Форма «защёлкивается»: как только она показана, программа, перезагруженная
/// после отметки или `program_changed`, её не заменяет — закрытием экрана
/// управляет `CompletionCubit`, иначе форма пропала бы раньше уведомления.
class CompleteDayScreen extends StatefulWidget {
  const CompleteDayScreen({
    super.key,
    required this.trainerId,
    required this.dayKey,
  });

  final String trainerId;
  final String dayKey;

  @override
  State<CompleteDayScreen> createState() => _CompleteDayScreenState();
}

class _CompleteDayScreenState extends State<CompleteDayScreen> {
  /// Форма уже показана: дальше экран перестраивается не по программе.
  bool _formShown = false;

  /// Программу можно отмечать: она назначена, день есть, его можно отметить и он
  /// ещё не выполнен.
  bool _canShowForm(TrainerProgram data) {
    final located = data.locate(widget.dayKey);
    return data.hasProgram &&
        located != null &&
        !data.isCompleted(located.day) &&
        data.completionTargetFor(widget.dayKey) != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ProgramCubit>();
    final back = RouteNames.workoutDayPath(widget.trainerId, widget.dayKey);

    return BlocBuilder<ProgramCubit, ProgramState>(
      buildWhen: (_, _) => !_formShown,
      builder: (context, state) {
        if (state is ProgramLoaded && _canShowForm(state.data)) {
          _formShown = true;
        }

        return switch (state) {
          ProgramLoading() => ProgramFrame(
            backFallback: back,
            child: const DaySkeleton(),
          ),
          ProgramFailed(:final failure) => ProgramFrame(
            backFallback: back,
            child: ErrorState(
              message: failure.message(l10n),
              onRetry: failure.canRetry ? cubit.load : null,
            ),
          ),
          ProgramLoaded(:final data) when !data.hasProgram => ProgramFrame(
            backFallback: back,
            child: NoProgramView(onRefresh: cubit.refresh),
          ),
          ProgramLoaded(:final data) when _canShowForm(data) =>
            CompletionScope(
              dayKey: widget.dayKey,
              child: CompleteDayForm(
                trainerId: widget.trainerId,
                dayKey: widget.dayKey,
                dayTitle: l10n.workoutDayTitle(
                  data.locate(widget.dayKey)!.weekNumber,
                  data.locate(widget.dayKey)!.day.dayNumber,
                ),
              ),
            ),
          ProgramLoaded(:final data) => ProgramFrame(
            backFallback: back,
            child: data.locate(widget.dayKey) != null &&
                    data.isCompleted(data.locate(widget.dayKey)!.day)
                ? EmptyState(
                    icon: Icons.check_circle_outline,
                    title: l10n.errorWorkoutAlreadyCompleted,
                  )
                : ErrorState(message: l10n.errorWorkoutDayNotFound),
          ),
        };
      },
    );
  }
}
