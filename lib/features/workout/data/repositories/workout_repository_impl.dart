import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/workout/data/datasources/workout_remote_datasource.dart';
import 'package:mentorix_app/features/workout/domain/repositories/workout_repository.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl({required WorkoutRemoteDataSource remote})
    : _remote = remote;

  final WorkoutRemoteDataSource _remote;

  @override
  Future<List<LinkedTrainer>> trainers() => _remote.trainers();
}
