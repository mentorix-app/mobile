import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/data/models/program_week_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/program.dart';

class ProgramModel extends Program {
  const ProgramModel({
    required super.id,
    required super.name,
    super.nameRu,
    super.weeks,
  });

  /// `name_ru` необязателен (на stage пуст у большинства программ). Категория,
  /// сложность, описание и `preview_image_url` не читаются.
  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    return ProgramModel(
      id: JsonReading.string(json, 'program_id'),
      name: JsonReading.string(json, 'name').trim(),
      nameRu: JsonReading.string(json, 'name_ru').trim(),
      weeks: [
        for (final item in JsonReading.objectsBySortOrder(json, 'weeks'))
          ProgramWeekModel.fromJson(item),
      ],
    );
  }
}
