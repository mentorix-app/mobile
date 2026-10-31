import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

/// Статистика клиента у тренера. Бросает только [WorkoutFailure].
abstract class StatsRepository {
  /// `GET /client/trainers/{trainer_id}/analytics`: прогресс, активность и до 30
  /// последних отметок с ответами тренера. Подписанная ссылка бота не
  /// используется.
  Future<ClientAnalytics> analytics(String trainerId);
}
