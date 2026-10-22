import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

sealed class TrainersState extends Equatable {
  const TrainersState();

  @override
  List<Object?> get props => [];
}

/// Первая загрузка: на экране скелетон.
class TrainersLoading extends TrainersState {
  const TrainersLoading();
}

/// Список получен. Пустой — активной связи с тренером нет.
///
/// [refreshFailure] — обновление не удалось, а показанный список остаётся:
/// экран сообщает об ошибке уведомлением и ничего не стирает.
class TrainersLoaded extends TrainersState {
  const TrainersLoaded(this.trainers, {this.refreshFailure});

  final List<LinkedTrainer> trainers;
  final WorkoutFailure? refreshFailure;

  @override
  List<Object?> get props => [trainers, refreshFailure];
}

/// Первая загрузка не удалась: на экране ошибка и «Повторить».
class TrainersFailed extends TrainersState {
  const TrainersFailed(this.failure);

  final WorkoutFailure failure;

  @override
  List<Object?> get props => [failure];
}
