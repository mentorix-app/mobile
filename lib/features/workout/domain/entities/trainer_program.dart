import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/program.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_assignment.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_day.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_week.dart';

/// День вместе с номером недели, в которой он лежит.
class LocatedDay extends Equatable {
  const LocatedDay({required this.weekNumber, required this.day});

  final int weekNumber;
  final ProgramDay day;

  @override
  List<Object?> get props => [weekNumber, day];
}

/// Ответ `GET /client/trainers/{trainer_id}/program`.
///
/// **Выполненность дня — только по `completed_days` с сервера** ([completedDayKeys]
/// по `day_key`): день могли отметить в Telegram-боте. Локально отметок нет.
class TrainerProgram extends Equatable {
  const TrainerProgram({
    required this.trainerId,
    this.trainerName = '',
    this.assignment,
    this.program,
    this.completedDayKeys = const {},
  });

  final String trainerId;

  /// Может быть пустым.
  final String trainerName;

  /// `null`, пока тренер программу не назначил (тогда и [program] `null`).
  final ProgramAssignment? assignment;
  final Program? program;

  /// `day_key` отмеченных дней текущего цикла. Может содержать дни, которых в
  /// программе уже нет (новая версия): в подсчёте они не участвуют.
  final Set<String> completedDayKeys;

  /// Назначение и программа есть. Одного без другого для экрана недостаточно.
  bool get hasProgram => assignment != null && program != null;

  List<ProgramWeek> get weeks => program?.weeks ?? const [];

  /// Тренировочные дни — с хотя бы одним блоком, как `total_training_days` на
  /// сервере. День отдыха в прогрессе не считается.
  Iterable<ProgramDay> get trainingDays => [
    for (final week in weeks) ...week.days.where((day) => day.isTraining),
  ];

  /// День по `day_key` (из адреса экрана) или `null`: дня нет в этой версии
  /// программы (тренер её поменял) либо ключ не тот. Пустой ключ не ищется.
  LocatedDay? locate(String dayKey) {
    if (dayKey.isEmpty) return null;

    for (final week in weeks) {
      for (final day in week.days) {
        if (day.dayKey == dayKey) {
          return LocatedDay(weekNumber: week.weekNumber, day: day);
        }
      }
    }
    return null;
  }

  bool isCompleted(ProgramDay day) =>
      day.dayKey.isNotEmpty && completedDayKeys.contains(day.dayKey);

  int get totalTrainingDays => trainingDays.length;

  /// Выполненные тренировочные дни. Ключ без дня в программе не считается.
  int get completedTrainingDays => trainingDays.where(isCompleted).length;

  /// Все тренировочные дни выполнены: тренер должен назначить следующую
  /// программу. Без тренировочных дней программа «пройденной» не бывает.
  bool get isFinished =>
      totalTrainingDays > 0 && completedTrainingDays >= totalTrainingDays;

  @override
  List<Object?> get props => [
    trainerId,
    trainerName,
    assignment,
    program,
    completedDayKeys,
  ];
}
