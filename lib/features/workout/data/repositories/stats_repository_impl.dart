import 'package:mentorix_app/features/workout/data/datasources/workout_remote_datasource.dart';
import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';
import 'package:mentorix_app/features/workout/domain/repositories/stats_repository.dart';

class StatsRepositoryImpl implements StatsRepository {
  StatsRepositoryImpl({required WorkoutRemoteDataSource remote})
    : _remote = remote;

  final WorkoutRemoteDataSource _remote;

  @override
  Future<ClientAnalytics> analytics(String trainerId) =>
      _remote.analytics(trainerId);
}
