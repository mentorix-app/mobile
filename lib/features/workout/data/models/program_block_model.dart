import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/data/models/program_exercise_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_block.dart';

class ProgramBlockModel extends ProgramBlock {
  const ProgramBlockModel({
    required super.id,
    required super.type,
    super.instruction,
    super.exercises,
  });

  /// Незнакомый `block_type` — [BlockType.unknown], экран не падает.
  /// `client_user_ids` и `created_at` не читаются: видимость блоков решает сервер.
  factory ProgramBlockModel.fromJson(Map<String, dynamic> json) {
    final rawType = JsonReading.optionalString(json, 'block_type');
    final type = BlockType.fromKey(rawType);
    if (type == BlockType.unknown) {
      JsonReading.skip('block_type', 'unknown type "${rawType ?? ''}" shown as a generic block');
    }

    return ProgramBlockModel(
      id: JsonReading.string(json, 'id'),
      type: type,
      instruction: JsonReading.userText(json, 'instruction').trim(),
      exercises: [
        for (final item in JsonReading.objectsBySortOrder(json, 'exercises'))
          ProgramExerciseModel.fromJson(item),
      ],
    );
  }
}
