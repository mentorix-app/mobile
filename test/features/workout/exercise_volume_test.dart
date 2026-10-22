import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/presentation/exercise_volume.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_en.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_ru.dart';

import '../../helpers/workout_builders.dart';

void main() {
  final en = AppLocalizationsEn();
  final ru = AppLocalizationsRu();

  List<String> texts(exercise, BlockType type, [l10n]) => [
    for (final item in exerciseVolume(l10n ?? en, exercise, type)) item.text,
  ];

  group('обычные блоки', () {
    test('оба поля — одна плашка «3 × 8-12»', () {
      final e = exercise('A', sets: '3', reps: '8-12');

      for (final type in BlockType.values.where((t) => t != BlockType.emom)) {
        expect(texts(e, type), ['3 × 8-12'], reason: '$type');
      }
    });

    test('значения показываются как есть: 5/4, 3-6, 10', () {
      expect(texts(exercise('A', sets: '5/4', reps: '3-6'), BlockType.single), ['5/4 × 3-6']);
      expect(texts(exercise('A', sets: '10', reps: '5/4'), BlockType.amrap), ['10 × 5/4']);
    });

    test('только sets — «Sets: 3» / «Подходы: 3»', () {
      final e = exercise('A', sets: '3');

      expect(texts(e, BlockType.single), ['Sets: 3']);
      expect(texts(e, BlockType.single, ru), ['Подходы: 3']);
    });

    test('только reps — «Reps: 15» / «Повторы: 15» (AMRAP без sets)', () {
      final e = exercise('A', reps: '15');

      expect(texts(e, BlockType.amrap), ['Reps: 15']);
      expect(texts(e, BlockType.amrap, ru), ['Повторы: 15']);
    });

    test('ни одного поля — пусто', () {
      expect(texts(exercise('A'), BlockType.single), isEmpty);
      expect(texts(exercise('A'), BlockType.emom), isEmpty);
    });

    test('русская локаль для обоих полей: «×» тот же, смысл для читалок свой', () {
      final items = exerciseVolume(ru, exercise('A', sets: '3', reps: '8-12'), BlockType.single);

      expect(items.single.text, '3 × 8-12');
      expect(items.single.semantics, 'Подходы 3, повторы 8-12');
    });

    test('для читалок: «Sets 5, reps 5»', () {
      final items = exerciseVolume(en, exercise('A', sets: '5', reps: '5'), BlockType.single);

      expect(items.single.semantics, 'Sets 5, reps 5');
    });

    test('у одиночных плашек подпись совпадает с текстом', () {
      final items = exerciseVolume(en, exercise('A', sets: '3'), BlockType.single);

      expect(items.single.semantics, items.single.text);
    });
  });

  group('EMOM: sets — раунды или минуты', () {
    test('обе величины — две плашки, «×» нет', () {
      final e = exercise('Kettlebell Swing', sets: '5', reps: '15');

      expect(texts(e, BlockType.emom), ['Rounds / minutes: 5', 'Reps: 15']);
      expect(texts(e, BlockType.emom, ru), ['Раунды / минуты: 5', 'Повторы: 15']);
    });

    test('только sets — раунды, подходов нет', () {
      final e = exercise('A', sets: '10');

      expect(texts(e, BlockType.emom), ['Rounds / minutes: 10']);
      expect(texts(e, BlockType.emom).join(), isNot(contains('Sets')));
    });

    test('только reps — повторы', () {
      expect(texts(exercise('A', reps: '5/4'), BlockType.emom), ['Reps: 5/4']);
    });

    test('те же данные в другом блоке — подходы', () {
      final e = exercise('A', sets: '5', reps: '15');

      expect(texts(e, BlockType.superset), ['5 × 15']);
      expect(texts(e, BlockType.single), ['5 × 15']);
    });
  });

  test('ExerciseVolumeItem сравнивается по значению', () {
    expect(const ExerciseVolumeItem('a'), const ExerciseVolumeItem('a'));
    expect(const ExerciseVolumeItem('a'), isNot(const ExerciseVolumeItem('b')));
  });
}
