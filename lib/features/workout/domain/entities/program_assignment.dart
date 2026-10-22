import 'package:equatable/equatable.dart';

/// Назначение программы клиенту (`assignment` в ответе программы).
///
/// Три идентификатора отправляются обратно при отметке дня: так сервер узнаёт,
/// что тренер не успел поменять программу (`409 program_changed`).
class ProgramAssignment extends Equatable {
  const ProgramAssignment({
    required this.assignmentId,
    required this.programVersionId,
    required this.completionCycleId,
    this.assignedAt,
  });

  final String assignmentId;
  final String programVersionId;

  /// Цикл прохождения: новый начинается, когда тренер назначает другую
  /// программу. Отметки `completed_days` относятся к нему.
  final String completionCycleId;
  final DateTime? assignedAt;

  /// Все три идентификатора на месте — день можно отметить.
  bool get canMarkDays =>
      assignmentId.isNotEmpty &&
      programVersionId.isNotEmpty &&
      completionCycleId.isNotEmpty;

  @override
  List<Object?> get props => [
    assignmentId,
    programVersionId,
    completionCycleId,
    assignedAt,
  ];
}
