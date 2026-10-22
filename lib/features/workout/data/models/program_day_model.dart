import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/data/models/program_block_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_day.dart';

class ProgramDayModel extends ProgramDay {
  const ProgramDayModel({
    required super.id,
    required super.dayKey,
    required super.dayNumber,
    super.blocks,
  });

  /// `blocks: []` — день отдыха. Нет `day_key` — день виден, но не отмечается.
  factory ProgramDayModel.fromJson(Map<String, dynamic> json) {
    return ProgramDayModel(
      id: JsonReading.string(json, 'id'),
      dayKey: JsonReading.optionalString(json, 'day_key') ?? '',
      dayNumber: JsonReading.integer(json, 'day_number'),
      blocks: [
        for (final item in JsonReading.objectsBySortOrder(json, 'blocks'))
          ProgramBlockModel.fromJson(item),
      ],
    );
  }
}
