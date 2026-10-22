import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_exercise.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Одна плашка объёма упражнения: [text] для глаз и [semantics] для чтения с
/// экрана.
class ExerciseVolumeItem {
  const ExerciseVolumeItem(this.text, {String? semantics})
    : semantics = semantics ?? text;

  final String text;
  final String semantics;

  @override
  bool operator ==(Object other) =>
      other is ExerciseVolumeItem &&
      other.text == text &&
      other.semantics == semantics;

  @override
  int get hashCode => Object.hash(text, semantics);

  @override
  String toString() => 'ExerciseVolumeItem($text)';
}

/// Подходы и повторы упражнения. `sets` и `reps` — строки (`3`, `5/4`, `8-12`), они
/// показываются как есть и могут отсутствовать.
///
/// * оба поля — одна плашка «3 × 8-12» (для чтения с экрана — «Подходы 3, повторы
///   8-12»);
/// * только `sets` — «Подходы: 3»; только `reps` — «Повторы: 15»;
/// * ни одного — пусто;
/// * **EMOM**: `sets` здесь — число раундов или минут, а не подходов, поэтому
///   плашки две: «Раунды / минуты: 5» и «Повторы: 15».
///
/// Вес, отдых и единицы («15 cal») в этих полях не помещаются — тренер пишет их в
/// `instruction`, он показывается рядом.
List<ExerciseVolumeItem> exerciseVolume(
  AppLocalizations l10n,
  ProgramExercise exercise,
  BlockType blockType,
) {
  final sets = exercise.sets;
  final reps = exercise.reps;

  if (blockType == BlockType.emom) {
    return [
      if (sets != null) ExerciseVolumeItem(l10n.exerciseRoundsLabel(sets)),
      if (reps != null) ExerciseVolumeItem(l10n.exerciseRepsLabel(reps)),
    ];
  }

  if (sets != null && reps != null) {
    return [
      ExerciseVolumeItem(
        '$sets × $reps',
        semantics: l10n.exerciseSetsRepsSemantics(sets, reps),
      ),
    ];
  }

  return [
    if (sets != null) ExerciseVolumeItem(l10n.exerciseSetsLabel(sets)),
    if (reps != null) ExerciseVolumeItem(l10n.exerciseRepsLabel(reps)),
  ];
}
