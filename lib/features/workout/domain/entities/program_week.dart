import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_day.dart';

/// Неделя программы: от одного до семи дней.
class ProgramWeek extends Equatable {
  const ProgramWeek({
    required this.id,
    required this.weekNumber,
    this.days = const [],
  });

  final String id;
  final int weekNumber;
  final List<ProgramDay> days;

  @override
  List<Object?> get props => [id, weekNumber, days];
}
