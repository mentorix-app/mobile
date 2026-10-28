import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/completion_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';

/// `CompletionCubit` на время экрана отметки. Создаётся один раз, когда программа
/// уже загружена: слепок для отправки берётся из неё в этот момент.
class CompletionScope extends StatelessWidget {
  const CompletionScope({super.key, required this.dayKey, required this.child});

  final String dayKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CompletionCubit>(
      create: (context) => GetIt.I<CompletionCubit>(
        param1: context.read<ProgramCubit>(),
        param2: dayKey,
      ),
      child: child,
    );
  }
}
