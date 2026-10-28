import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/workout/data/datasources/workout_remote_datasource.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_target.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/entities/workout_completion.dart';
import 'package:mentorix_app/features/workout/domain/repositories/workout_repository.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl({required WorkoutRemoteDataSource remote})
    : _remote = remote;

  final WorkoutRemoteDataSource _remote;

  @override
  Future<List<LinkedTrainer>> trainers() => _remote.trainers();

  @override
  Future<TrainerProgram> program(String trainerId) =>
      _remote.program(trainerId);

  @override
  Future<WorkoutCompletion> completeDay({
    required String trainerId,
    required CompletionTarget target,
    required String resultText,
  }) => _remote.completeDay(
    trainerId: trainerId,
    target: target,
    resultText: resultText,
  );
}
