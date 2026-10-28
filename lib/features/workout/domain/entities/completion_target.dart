import 'package:equatable/equatable.dart';

/// Слепок того, что клиент видел, когда открыл экран отметки: назначение, версия
/// программы, цикл прохождения и день. Эти четыре значения уходят в
/// `POST …/completions` без изменений: если тренер успел поменять программу, сервер
/// ответит `409 program_changed`, и клиент не отметит то, чего не видел.
class CompletionTarget extends Equatable {
  const CompletionTarget({
    required this.assignmentId,
    required this.programVersionId,
    required this.completionCycleId,
    required this.dayKey,
  });

  final String assignmentId;
  final String programVersionId;
  final String completionCycleId;
  final String dayKey;

  @override
  List<Object?> get props => [
    assignmentId,
    programVersionId,
    completionCycleId,
    dayKey,
  ];
}
