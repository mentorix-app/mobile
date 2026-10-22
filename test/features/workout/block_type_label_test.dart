import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/presentation/block_type_label.dart';
import 'package:mentorix_app/features/workout/presentation/localized_name.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_en.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_ru.dart';

void main() {
  final ru = AppLocalizationsRu();
  final en = AppLocalizationsEn();

  group('подписи типов блоков (docs/BRAND.md)', () {
    test('у каждого значения есть непустая подпись в обеих локалях', () {
      for (final type in BlockType.values) {
        expect(type.label(ru), isNotEmpty, reason: '$type ru');
        expect(type.label(en), isNotEmpty, reason: '$type en');
      }
    });

    test('подписи разных типов различаются (кроме совпадающих по смыслу EMOM/AMRAP/Death By)', () {
      for (final l10n in [ru, en]) {
        final labels = [for (final t in BlockType.values) t.label(l10n)];
        expect(labels.toSet(), hasLength(labels.length), reason: l10n.localeName);
      }
    });

    test('русские названия', () {
      expect({for (final t in BlockType.values) t: t.label(ru)}, {
        BlockType.single: 'Одиночный',
        BlockType.emom: 'EMOM',
        BlockType.amrap: 'AMRAP',
        BlockType.forTime: 'На время',
        BlockType.intervals: 'Интервалы',
        BlockType.chipper: 'Чиппер',
        BlockType.ladder: 'Лесенка',
        BlockType.deathBy: 'Death By',
        BlockType.superset: 'Суперсет',
        BlockType.complex: 'Комплекс',
        BlockType.skillWork: 'Работа над навыком',
        BlockType.strength: 'Силовая часть',
        BlockType.conditioning: 'Кондиционная часть',
        BlockType.gymnastics: 'Гимнастика',
        BlockType.weightlifting: 'Тяжёлая атлетика',
        BlockType.unknown: 'Блок',
      });
    });

    test('английские названия как в дашборде', () {
      expect(BlockType.forTime.label(en), 'For Time');
      expect(BlockType.deathBy.label(en), 'Death By');
      expect(BlockType.skillWork.label(en), 'Skill Work');
      expect(BlockType.unknown.label(en), 'Block');
    });

    test('single — обычное упражнение, остальные — группы', () {
      expect(BlockType.single.isSingle, isTrue);
      expect([for (final t in BlockType.values) if (t.isSingle) t], [BlockType.single]);
    });
  });

  group('localizedName', () {
    String pick(String name, String nameRu, String locale) =>
        localizedName(name: name, nameRu: nameRu, localeName: locale);

    test('русский и заполненное name_ru — name_ru', () {
      expect(pick('Squat', 'Приседания', 'ru'), 'Приседания');
    });

    test('русский, name_ru пусто или из пробелов — name', () {
      expect(pick('Squat', '', 'ru'), 'Squat');
      expect(pick('Squat', '   ', 'ru'), 'Squat');
    });

    test('английский — всегда name', () {
      expect(pick('Squat', 'Приседания', 'en'), 'Squat');
    });

    test('name пусто, name_ru есть — name_ru на любом языке', () {
      expect(pick('', 'Приседания', 'en'), 'Приседания');
    });

    test('оба пусты — пустая строка', () {
      expect(pick('', '', 'ru'), '');
    });

    test('лишние пробелы обрезаются', () {
      expect(pick('  Squat ', '', 'en'), 'Squat');
    });
  });
}
