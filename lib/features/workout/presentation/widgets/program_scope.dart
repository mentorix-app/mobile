import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_refresh_on_resume.dart';

/// Один `ProgramCubit` на все экраны программы выбранного тренера (программа,
/// день, отметка): их `Navigator`-страницы лежат под этим виджетом. Ключ по
/// `trainerId` не даёт переиспользовать кубит другого тренера.
class ProgramScope extends StatelessWidget {
  const ProgramScope({super.key, required this.trainerId, required this.child});

  final String trainerId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProgramCubit>(
      key: ValueKey(trainerId),
      create: (_) => GetIt.I<ProgramCubit>(param1: trainerId)..load(),
      child: ProgramRefreshOnResume(child: child),
    );
  }
}
