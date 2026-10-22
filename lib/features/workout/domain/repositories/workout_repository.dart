import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

/// Тренировки клиента. Бросает только [WorkoutFailure].
abstract class WorkoutRepository {
  /// `GET /client/trainers`: тренеры клиента, новые связи первыми. Пустой список —
  /// активной связи нет.
  Future<List<LinkedTrainer>> trainers();
}
