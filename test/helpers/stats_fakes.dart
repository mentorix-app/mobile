import 'dart:async';

import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/repositories/stats_repository.dart';

/// Репозиторий статистики без сети.
class FakeStatsRepository implements StatsRepository {
  ClientAnalytics result = const ClientAnalytics();

  /// Если задан — `analytics()` бросает его.
  WorkoutFailure? failure;

  /// Если задан — `analytics()` ждёт его завершения.
  Completer<void>? gate;

  int calls = 0;
  final List<String> trainerIds = [];

  @override
  Future<ClientAnalytics> analytics(String trainerId) async {
    calls++;
    trainerIds.add(trainerId);
    final snapshot = result;
    final wait = gate;
    if (wait != null) await wait.future;

    final error = failure;
    if (error != null) throw error;
    return snapshot;
  }
}
