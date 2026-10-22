import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_exercise.dart';

/// Блок дня: одно упражнение без группы (`single`) или группа (EMOM, AMRAP, …).
class ProgramBlock extends Equatable {
  const ProgramBlock({
    required this.id,
    required this.type,
    this.instruction = '',
    this.exercises = const [],
  });

  final String id;
  final BlockType type;

  /// Инструкция блока; пусто — не показывается.
  final String instruction;

  final List<ProgramExercise> exercises;

  @override
  List<Object?> get props => [id, type, instruction, exercises];
}
