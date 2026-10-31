import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_record.dart';

/// Прогресс по одной неделе назначенной версии.
class WeekProgress extends Equatable {
  const WeekProgress({
    required this.weekNumber,
    required this.totalDays,
    required this.completedDays,
  });

  final int weekNumber;
  final int totalDays;
  final int completedDays;

  @override
  List<Object?> get props => [weekNumber, totalDays, completedDays];
}

/// Текущая программа: прогресс текущего цикла по назначенной версии.
class AssignmentProgress extends Equatable {
  const AssignmentProgress({
    required this.programName,
    required this.programNameRu,
    required this.completedDays,
    required this.totalTrainingDays,
    required this.completionPercent,
    this.weeks = const [],
  });

  final String programName;
  final String programNameRu;
  final int completedDays;

  /// Дни хотя бы с одним блоком в назначенной версии (так же считает программа).
  final int totalTrainingDays;

  /// 0–100. Приходит целым (`0`) или дробным (`66.7`); если сервер не прислал —
  /// считается от дней.
  final double completionPercent;
  final List<WeekProgress> weeks;

  @override
  List<Object?> get props => [
    programName,
    programNameRu,
    completedDays,
    totalTrainingDays,
    completionPercent,
    weeks,
  ];
}

/// Отметки по одной программе (за всё время).
class ProgramActivity extends Equatable {
  const ProgramActivity({
    required this.programName,
    required this.programNameRu,
    required this.totalCompletions,
  });

  final String programName;
  final String programNameRu;
  final int totalCompletions;

  @override
  List<Object?> get props => [programName, programNameRu, totalCompletions];
}

/// Активность с этим тренером за всё время — по всем циклам и программам.
class ClientActivity extends Equatable {
  const ClientActivity({
    this.totalCompletions = 0,
    this.completionsLast7Days = 0,
    this.completionsLast30Days = 0,
    this.firstCompletedAt,
    this.lastCompletedAt,
    this.weekStreak = 0,
    this.byProgram = const [],
  });

  final int totalCompletions;
  final int completionsLast7Days;
  final int completionsLast30Days;
  final DateTime? firstCompletedAt;
  final DateTime? lastCompletedAt;

  /// Недель подряд (пн–вс по UTC) с хотя бы одной тренировкой.
  final int weekStreak;
  final List<ProgramActivity> byProgram;

  @override
  List<Object?> get props => [
    totalCompletions,
    completionsLast7Days,
    completionsLast30Days,
    firstCompletedAt,
    lastCompletedAt,
    weekStreak,
    byProgram,
  ];
}

/// Ответ `GET /client/trainers/{trainer_id}/analytics`: прогресс, активность и до
/// 30 последних отметок с ответами тренера (новые сверху).
class ClientAnalytics extends Equatable {
  const ClientAnalytics({
    this.currentAssignment,
    this.activity = const ClientActivity(),
    this.recentCompletions = const [],
  });

  /// `null`, пока программа не назначена.
  final AssignmentProgress? currentAssignment;
  final ClientActivity activity;
  final List<CompletionRecord> recentCompletions;

  @override
  List<Object?> get props => [currentAssignment, activity, recentCompletions];
}
