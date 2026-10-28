import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/domain/entities/workout_completion.dart';

class WorkoutCompletionModel extends WorkoutCompletion {
  const WorkoutCompletionModel({
    required super.id,
    required super.dayKey,
    super.weekNumber,
    super.dayNumber,
    super.completedAt,
    super.resultText,
  });

  /// Ответ 201: `{id, day_key, week_number, day_number, completed_at, result_text}`.
  /// Разбор терпимый: отметка к этому моменту уже записана на сервере, и
  /// неожиданный вид ответа не должен выглядеть как ошибка отметки. Нет
  /// `day_key` — берётся тот, что отправили ([fallbackDayKey]).
  factory WorkoutCompletionModel.fromJson(
    Map<String, dynamic> json, {
    required String fallbackDayKey,
  }) {
    return WorkoutCompletionModel(
      id: JsonReading.string(json, 'id'),
      dayKey: JsonReading.optionalString(json, 'day_key') ?? fallbackDayKey,
      weekNumber: json['week_number'] is num
          ? JsonReading.integer(json, 'week_number')
          : null,
      dayNumber: json['day_number'] is num
          ? JsonReading.integer(json, 'day_number')
          : null,
      completedAt: JsonReading.dateTime(json, 'completed_at'),
      resultText: JsonReading.userText(json, 'result_text'),
    );
  }
}
