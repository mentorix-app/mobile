import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/data/models/trainer_comment_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_record.dart';

class CompletionRecordModel extends CompletionRecord {
  const CompletionRecordModel({
    required super.id,
    super.completedAt,
    super.programName,
    super.programNameRu,
    super.weekNumber,
    super.dayNumber,
    super.resultText,
    super.comments,
  });

  /// `is_current_cycle` не читается: клиенту бейдж «Текущий цикл» не показывается.
  /// `comments` нет или не список — ответов нет.
  factory CompletionRecordModel.fromJson(Map<String, dynamic> json) {
    return CompletionRecordModel(
      id: JsonReading.string(json, 'id'),
      completedAt: JsonReading.dateTime(json, 'completed_at'),
      programName: JsonReading.string(json, 'program_name').trim(),
      programNameRu: JsonReading.string(json, 'program_name_ru').trim(),
      weekNumber: JsonReading.integer(json, 'week_number'),
      dayNumber: JsonReading.integer(json, 'day_number'),
      resultText: JsonReading.userText(json, 'result_text').trim(),
      comments: [
        for (final item in JsonReading.objects(json, 'comments'))
          TrainerCommentModel.fromJson(item),
      ],
    );
  }
}
