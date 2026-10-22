import 'package:equatable/equatable.dart';

/// Упражнение в блоке дня. Картинок и видео в клиентском API нет.
class ProgramExercise extends Equatable {
  const ProgramExercise({
    required this.id,
    required this.name,
    this.nameRu = '',
    this.sets,
    this.reps,
    this.instruction = '',
  });

  final String id;

  /// `exercise_name`: заполнено всегда.
  final String name;

  /// `exercise_name_ru`: может быть пустым, тогда показывается [name].
  final String nameRu;

  /// Строки вида `3`, `5/4`, `8-12`; `null` — не задано. Смысл зависит от типа
  /// блока: в EMOM это число раундов или минут, а не подходов.
  final String? sets;
  final String? reps;

  /// Вес, отдых, единицы («15 cal») — тренер пишет только здесь. Пусто — не
  /// показывается.
  final String instruction;

  @override
  List<Object?> get props => [id, name, nameRu, sets, reps, instruction];
}
