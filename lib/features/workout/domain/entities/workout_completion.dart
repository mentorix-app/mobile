import 'package:equatable/equatable.dart';

/// Ответ `201` на отметку дня. Поля нужны только для отладки и тестов: экран
/// ничего из них не показывает, а выполненность берёт из `completed_days`.
class WorkoutCompletion extends Equatable {
  const WorkoutCompletion({
    required this.id,
    required this.dayKey,
    this.weekNumber,
    this.dayNumber,
    this.completedAt,
    this.resultText = '',
  });

  final String id;
  final String dayKey;
  final int? weekNumber;
  final int? dayNumber;
  final DateTime? completedAt;
  final String resultText;

  @override
  List<Object?> get props => [
    id,
    dayKey,
    weekNumber,
    dayNumber,
    completedAt,
    resultText,
  ];
}
