import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/analytics_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/analytics_state.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_frame.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/stats_skeleton.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/stats_view.dart';
import 'package:mentorix_app/features/workout/presentation/workout_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Статистика и ответы тренера (`/trainers/:trainerId/stats`). Только чтение:
/// ответить тренеру нельзя. Кубит даёт маршрут.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.trainerId});

  final String trainerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AnalyticsCubit>();
    final back = RouteNames.trainerProgramPath(trainerId);

    return BlocConsumer<AnalyticsCubit, AnalyticsState>(
      listener: (context, state) => switch (state) {
        AnalyticsLoaded(refreshFailure: final failure?) => AppSnackBar.showError(
          context,
          failure.message(l10n),
        ),
        _ => null,
      },
      builder: (context, state) => switch (state) {
        AnalyticsLoading() => ProgramFrame(
          title: l10n.statsTitle,
          backFallback: back,
          child: const StatsSkeleton(),
        ),
        AnalyticsFailed(:final failure) => ProgramFrame(
          title: l10n.statsTitle,
          backFallback: back,
          child: ErrorState(
            message: failure.message(l10n),
            onRetry: failure.canRetry ? cubit.load : null,
          ),
        ),
        AnalyticsLoaded(:final data) => Scaffold(
          body: SafeArea(
            top: false,
            child: StatsView(
              trainerId: trainerId,
              data: data,
              onRefresh: cubit.refresh,
            ),
          ),
        ),
      },
    );
  }
}
