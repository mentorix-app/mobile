import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_target.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/entities/workout_completion.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

/// Тренировки клиента. Бросает только [WorkoutFailure].
abstract class WorkoutRepository {
  /// `GET /client/trainers`: тренеры клиента, новые связи первыми. Пустой список —
  /// активной связи нет.
  Future<List<LinkedTrainer>> trainers();

  /// `GET /client/trainers/{trainer_id}/program`: программа клиента у тренера
  /// с отметками выполненных дней.
  Future<TrainerProgram> program(String trainerId);

  /// `POST /client/trainers/{trainer_id}/completions`: отметить день с текстом
  /// результата. Отменить отметку нельзя. Ошибки: `program_changed`,
  /// `workout_already_completed`, `day_not_found` и др.
  Future<WorkoutCompletion> completeDay({
    required String trainerId,
    required CompletionTarget target,
    required String resultText,
  });
}
