import 'package:mentorix_app/features/workout/domain/entities/completion_target.dart';
import 'package:mentorix_app/features/workout/domain/entities/workout_completion.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/repositories/workout_repository.dart';
import 'package:mentorix_app/features/workout/domain/workout_text.dart';

/// Отметка дня выполненным.
///
/// Готовит текст так, как требует сервер (`docs/domain/analytics.md`): убирает
/// запрещённые управляющие символы (`\n`, `\r`, `\t` остаются), обрезает пробелы по
/// краям и проверяет длину — от 1 до 1000 символов Unicode. Пустой или слишком
/// длинный текст не уходит на сервер: [WorkoutInvalidResultFailure] без запроса.
///
/// [target] — слепок назначения, версии, цикла и дня из программы, которую клиент
/// видел; он отправляется без изменений.
class CompleteWorkoutDay {
  const CompleteWorkoutDay(this._repository);

  final WorkoutRepository _repository;

  Future<WorkoutCompletion> call({
    required String trainerId,
    required CompletionTarget target,
    required String text,
  }) async {
    final prepared = WorkoutText.prepareResult(text);
    if (!WorkoutText.isValidResult(prepared)) {
      throw const WorkoutInvalidResultFailure();
    }

    return _repository.completeDay(
      trainerId: trainerId,
      target: target,
      resultText: prepared,
    );
  }
}
