import 'package:mentorix_app/features/workout/data/models/completion_record_model.dart';
import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';

class ClientAnalyticsModel extends ClientAnalytics {
  const ClientAnalyticsModel({
    super.currentAssignment,
    super.activity,
    super.recentCompletions,
  });

  /// Любая часть может отсутствовать или быть `null`: экран показывает то, что есть.
  /// `client`, `trainer` и `expires_at` не читаются.
  factory ClientAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final assignment = JsonReading.object(json, 'current_assignment');
    final activity = JsonReading.object(json, 'activity');

    return ClientAnalyticsModel(
      currentAssignment: assignment == null ? null : _assignment(assignment),
      activity: activity == null ? const ClientActivity() : _activity(activity),
      recentCompletions: [
        for (final item in JsonReading.objects(json, 'recent_completions'))
          CompletionRecordModel.fromJson(item),
      ],
    );
  }

  static AssignmentProgress _assignment(Map<String, dynamic> json) {
    final progress = JsonReading.object(json, 'progress') ?? const {};
    final done = JsonReading.integer(progress, 'completed_days');
    final total = JsonReading.integer(progress, 'total_training_days');

    return AssignmentProgress(
      programName: JsonReading.string(json, 'program_name').trim(),
      programNameRu: JsonReading.string(json, 'program_name_ru').trim(),
      completedDays: done,
      totalTrainingDays: total,
      // `0` приходит целым, `66.7` — дробным; нет значения — считаем от дней.
      completionPercent:
          JsonReading.number(progress, 'completion_percent') ??
          (total > 0 ? (done / total * 100).clamp(0, 100).toDouble() : 0),
      weeks: [
        for (final week in JsonReading.objects(progress, 'weeks'))
          WeekProgress(
            weekNumber: JsonReading.integer(week, 'week_number'),
            totalDays: JsonReading.integer(week, 'total_days'),
            completedDays: JsonReading.integer(week, 'completed_days'),
          ),
      ],
    );
  }

  static ClientActivity _activity(Map<String, dynamic> json) {
    return ClientActivity(
      totalCompletions: JsonReading.integer(json, 'total_completions'),
      completionsLast7Days: JsonReading.integer(json, 'completions_last_7_days'),
      completionsLast30Days: JsonReading.integer(json, 'completions_last_30_days'),
      firstCompletedAt: JsonReading.dateTime(json, 'first_completed_at'),
      lastCompletedAt: JsonReading.dateTime(json, 'last_completed_at'),
      weekStreak: JsonReading.integer(json, 'week_streak'),
      byProgram: [
        for (final item in JsonReading.objects(json, 'by_program'))
          ProgramActivity(
            programName: JsonReading.string(item, 'program_name').trim(),
            programNameRu: JsonReading.string(item, 'program_name_ru').trim(),
            totalCompletions: JsonReading.integer(item, 'total_completions'),
          ),
      ],
    );
  }
}
