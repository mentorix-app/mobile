import 'dart:async';

import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/repositories/workout_repository.dart';

/// Репозиторий тренировок без сети. Что вернуть и сколько раз спросили — в полях.
class FakeWorkoutRepository implements WorkoutRepository {
  List<LinkedTrainer> trainersResult = const [];

  /// Если задан — `trainers()` бросает его.
  WorkoutFailure? trainersFailure;

  /// Если задан — `trainers()` ждёт его завершения (экран остаётся в загрузке).
  Completer<void>? trainersGate;

  int trainersCalls = 0;

  @override
  Future<List<LinkedTrainer>> trainers() async {
    trainersCalls++;
    final gate = trainersGate;
    if (gate != null) await gate.future;

    final failure = trainersFailure;
    if (failure != null) throw failure;
    return trainersResult;
  }
}

const aziz = LinkedTrainer(
  trainerId: '404dd1be-d973-4b97-8294-28a9e1fe38a9',
  trainerDisplayName: 'Aziz Geidar',
);
