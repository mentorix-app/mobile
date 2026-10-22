import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_assignment.dart';

class ProgramAssignmentModel extends ProgramAssignment {
  const ProgramAssignmentModel({
    required super.assignmentId,
    required super.programVersionId,
    required super.completionCycleId,
    super.assignedAt,
  });

  /// Отсутствующий идентификатор — пустая строка: программу видно, но отметить
  /// день нельзя ([ProgramAssignment.canMarkDays]). `program_id` не читается:
  /// он дублирует `program.program_id`.
  factory ProgramAssignmentModel.fromJson(Map<String, dynamic> json) {
    return ProgramAssignmentModel(
      assignmentId: JsonReading.string(json, 'assignment_id'),
      programVersionId: JsonReading.string(json, 'program_version_id'),
      completionCycleId: JsonReading.string(json, 'completion_cycle_id'),
      assignedAt: JsonReading.dateTime(json, 'assigned_at'),
    );
  }
}
