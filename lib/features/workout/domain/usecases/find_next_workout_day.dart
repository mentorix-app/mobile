import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_day.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';

/// Найденный день: куда подсказать идти дальше.
class NextWorkoutDay extends Equatable {
  const NextWorkoutDay({required this.weekNumber, required this.day});

  final int weekNumber;
  final ProgramDay day;

  @override
  List<Object?> get props => [weekNumber, day];
}

/// Первый невыполненный тренировочный день по порядку недель и дней.
///
/// Это подсказка (стартовая неделя, кнопка «Продолжить»), а не замок: дни можно
/// выполнять в любом порядке. Дни отдыха пропускаются, выполненность берётся из
/// `completed_days`. Все выполнены, дней нет или программы нет — `null`.
class FindNextWorkoutDay {
  const FindNextWorkoutDay();

  NextWorkoutDay? call(TrainerProgram program) {
    for (final week in program.weeks) {
      for (final day in week.days) {
        if (day.isTraining && !program.isCompleted(day)) {
          return NextWorkoutDay(weekNumber: week.weekNumber, day: day);
        }
      }
    }
    return null;
  }
}
