import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/data/models/program_day_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_week.dart';

class ProgramWeekModel extends ProgramWeek {
  const ProgramWeekModel({
    required super.id,
    required super.weekNumber,
    super.days,
  });

  /// В неделе от одного до семи дней: их число не зашито.
  factory ProgramWeekModel.fromJson(Map<String, dynamic> json) {
    return ProgramWeekModel(
      id: JsonReading.string(json, 'id'),
      weekNumber: JsonReading.integer(json, 'week_number'),
      days: [
        for (final item in JsonReading.objectsBySortOrder(json, 'days'))
          ProgramDayModel.fromJson(item),
      ],
    );
  }
}
