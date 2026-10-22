import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/features/theme/presentation/widgets/theme_mode_button.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/trainers_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/trainers_state.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/no_trainer_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/trainers_list.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/trainers_skeleton.dart';
import 'package:mentorix_app/features/workout/presentation/workout_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Главный экран клиента: его тренеры (`GET /client/trainers`). Список
/// показывается и при одном тренере. Профиль и переключатель темы — в шапке.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TrainersCubit>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trainersTitle),
        actions: [
          const ThemeModeButton(),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: l10n.profileOpenAction,
            onPressed: () => context.push(RouteNames.profile),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<TrainersCubit, TrainersState>(
          listener: (context, state) => switch (state) {
            TrainersLoaded(refreshFailure: final failure?) =>
              AppSnackBar.showError(context, failure.message(l10n)),
            _ => null,
          },
          builder: (context, state) => switch (state) {
            TrainersLoading() => const TrainersSkeleton(),
            TrainersFailed(:final failure) => ErrorState(
              message: failure.message(l10n),
              onRetry: cubit.load,
            ),
            TrainersLoaded(trainers: final trainers) when trainers.isEmpty =>
              NoTrainerView(
                onRefresh: cubit.refresh,
                onEnterInvite: () => context.push(RouteNames.invite),
              ),
            TrainersLoaded(trainers: final trainers) => TrainersList(
              trainers: trainers,
              onRefresh: cubit.refresh,
              onTrainerTap: (trainer) => context.push(
                RouteNames.trainerProgramPath(trainer.trainerId),
              ),
            ),
          },
        ),
      ),
    );
  }
}
