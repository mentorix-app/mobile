import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/data/models/program_assignment_model.dart';
import 'package:mentorix_app/features/workout/data/models/program_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';

class TrainerProgramModel extends TrainerProgram {
  const TrainerProgramModel({
    required super.trainerId,
    super.trainerName,
    super.assignment,
    super.program,
    super.completedDayKeys,
  });

  /// [trainerId] — из пути запроса, а не из ответа.
  ///
  /// `assignment` и `program` — `null`, пока тренер программу не назначил: это не
  /// ошибка. `completed_days` — список объектов с `day_key`; пустой, отсутствующий
  /// или с неожиданными элементами не роняет разбор.
  factory TrainerProgramModel.fromJson(
    Map<String, dynamic> json, {
    required String trainerId,
  }) {
    final assignment = JsonReading.object(json, 'assignment');
    final program = JsonReading.object(json, 'program');

    return TrainerProgramModel(
      trainerId: trainerId,
      trainerName: JsonReading.optionalString(json, 'trainer_display_name') ?? '',
      assignment: assignment == null
          ? null
          : ProgramAssignmentModel.fromJson(assignment),
      program: program == null ? null : ProgramModel.fromJson(program),
      completedDayKeys: {
        for (final item in JsonReading.objects(json, 'completed_days'))
          ?JsonReading.optionalString(item, 'day_key'),
      },
    );
  }
}
