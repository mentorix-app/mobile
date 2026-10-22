import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_state.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_skeleton.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/no_program_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_frame.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/rest_day_view.dart';
import 'package:mentorix_app/features/workout/presentation/workout_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// День программы: блоки и упражнения. День ищется в уже загруженной программе по
/// `day_key` из адреса; кубит общий с экраном программы (`ProgramScope`). Если
/// программу ещё не загрузили (экран восстановлен системой), она грузится здесь
/// же, пока показан скелетон.
///
/// Нет дня в этой версии программы (тренер её поменял) — «Этого дня больше нет»
/// без «Повторить». Обновляется свайпом вниз.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.trainerId, required this.dayKey});

  final String trainerId;
  final String dayKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ProgramCubit>();
    final back = RouteNames.trainerProgramPath(trainerId);

    return BlocConsumer<ProgramCubit, ProgramState>(
      listener: (context, state) => switch (state) {
        ProgramLoaded(refreshFailure: final failure?) =>
          AppSnackBar.showError(context, failure.message(l10n)),
        _ => null,
      },
      builder: (context, state) => switch (state) {
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
        ProgramLoaded(:final data) => switch (data.locate(dayKey)) {
          null => ProgramFrame(
            backFallback: back,
            child: ErrorState(message: l10n.errorWorkoutDayNotFound),
          ),
          final located => Scaffold(
            body: SafeArea(
              top: false,
              child: located.day.isRest
                  ? RestDayView(
                      title: l10n.workoutDayTitle(
                        located.weekNumber,
                        located.day.dayNumber,
                      ),
                      trainerId: trainerId,
                      onRefresh: cubit.refresh,
                    )
                  : DayView(
                      title: l10n.workoutDayTitle(
                        located.weekNumber,
                        located.day.dayNumber,
                      ),
                      trainerId: trainerId,
                      day: located.day,
                      completed: data.isCompleted(located.day),
                      onRefresh: cubit.refresh,
                    ),
            ),
          ),
        },
      },
    );
  }
}
