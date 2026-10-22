import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

sealed class ProgramState extends Equatable {
  const ProgramState();

  @override
  List<Object?> get props => [];
}

/// Первая загрузка: на экране скелетон.
class ProgramLoading extends ProgramState {
  const ProgramLoading();
}

/// Программа получена. [TrainerProgram.hasProgram] `false` — тренер программу
/// ещё не назначил (не ошибка).
///
/// [refreshFailure] — обновление не удалось, а показанные данные остаются:
/// экран сообщает об ошибке уведомлением и ничего не стирает.
class ProgramLoaded extends ProgramState {
  const ProgramLoaded(this.data, {this.refreshFailure});

  final TrainerProgram data;
  final WorkoutFailure? refreshFailure;

  @override
  List<Object?> get props => [data, refreshFailure];
}

/// Первая загрузка не удалась: на экране ошибка (с «Повторить», если повтор
/// имеет смысл).
class ProgramFailed extends ProgramState {
  const ProgramFailed(this.failure);

  final WorkoutFailure failure;

  @override
  List<Object?> get props => [failure];
}
