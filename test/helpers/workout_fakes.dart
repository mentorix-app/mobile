import 'dart:async';

import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
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

  /// Ответ `program()`. По умолчанию — тренер без назначенной программы.
  TrainerProgram programResult = const TrainerProgram(trainerId: 'aziz');

  /// Если задан — `program()` бросает его.
  WorkoutFailure? programFailure;

  /// Если задан — `program()` ждёт его завершения.
  Completer<void>? programGate;

  int programCalls = 0;
  final List<String> programTrainerIds = [];

  @override
  Future<List<LinkedTrainer>> trainers() async {
    trainersCalls++;
    final gate = trainersGate;
    if (gate != null) await gate.future;

    final failure = trainersFailure;
    if (failure != null) throw failure;
    return trainersResult;
  }

  @override
  Future<TrainerProgram> program(String trainerId) async {
    programCalls++;
    programTrainerIds.add(trainerId);
    final gate = programGate;
    if (gate != null) await gate.future;

    final failure = programFailure;
    if (failure != null) throw failure;
    return programResult;
  }
}

const aziz = LinkedTrainer(
  trainerId: '404dd1be-d973-4b97-8294-28a9e1fe38a9',
  trainerDisplayName: 'Aziz Geidar',
);
