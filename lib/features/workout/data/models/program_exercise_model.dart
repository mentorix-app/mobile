import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_exercise.dart';

class ProgramExerciseModel extends ProgramExercise {
  const ProgramExerciseModel({
    required super.id,
    required super.name,
    super.nameRu,
    super.sets,
    super.reps,
    super.instruction,
  });

  /// `sets` и `reps` — строки, могут отсутствовать, быть `null` или пустыми
  /// (у AMRAP в живом ответе нет ключа `sets`); `instruction` — пустая строка
  /// или тоже отсутствует.
  factory ProgramExerciseModel.fromJson(Map<String, dynamic> json) {
    return ProgramExerciseModel(
      id: JsonReading.string(json, 'id'),
      name: JsonReading.string(json, 'exercise_name').trim(),
      nameRu: JsonReading.string(json, 'exercise_name_ru').trim(),
      sets: JsonReading.volume(json, 'sets'),
      reps: JsonReading.volume(json, 'reps'),
      instruction: JsonReading.userText(json, 'instruction').trim(),
    );
  }
}
