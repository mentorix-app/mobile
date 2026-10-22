import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_state.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/no_program_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_frame.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_skeleton.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_view.dart';
import 'package:mentorix_app/features/workout/presentation/workout_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Программа клиента у тренера: недели и дни. Кубит даёт `ProgramScope`.
///
/// Когда программа получена — шапка `SliverAppBar.large` с названием; пока
/// загрузка, ошибка или программы нет — обычная шапка со словом «Программа»
/// (`ProgramFrame`). Кнопка «назад» есть в обоих случаях.
class ProgramScreen extends StatelessWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ProgramCubit>();

    return BlocConsumer<ProgramCubit, ProgramState>(
      listener: (context, state) => switch (state) {
        ProgramLoaded(refreshFailure: final failure?) =>
          AppSnackBar.showError(context, failure.message(l10n)),
        _ => null,
      },
      builder: (context, state) => switch (state) {
        ProgramLoaded(:final data) when data.hasProgram => Scaffold(
          // Верхний отступ занимает сама шапка.
          body: SafeArea(
            top: false,
            child: ProgramView(data: data, onRefresh: cubit.refresh),
          ),
        ),
        ProgramLoading() => const ProgramFrame(child: ProgramSkeleton()),
        ProgramFailed(:final failure) => ProgramFrame(
          child: ErrorState(
            message: failure.message(l10n),
            onRetry: failure.canRetry ? cubit.load : null,
          ),
        ),
        ProgramLoaded() => ProgramFrame(
          child: NoProgramView(onRefresh: cubit.refresh),
        ),
      },
    );
  }
}
