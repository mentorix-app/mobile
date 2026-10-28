import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/domain/workout_text.dart';
import 'package:mentorix_app/features/workout/presentation/max_code_points_formatter.dart';

void main() {
  group('characterCount — символы Unicode, как считает сервер', () {
    test('обычный текст и кириллица', () {
      expect(WorkoutText.characterCount(''), 0);
      expect(WorkoutText.characterCount('abc'), 3);
      expect(WorkoutText.characterCount('Привет'), 6);
    });

    test('эмодзи вне BMP — один символ, хотя String.length даёт два', () {
      expect('💪'.length, 2);
      expect(WorkoutText.characterCount('💪'), 1);
      expect(WorkoutText.characterCount('💪💪💪'), 3);
    });

    test('составной эмодзи считается по code points, а не графемам', () {
      // Семья: 3 человека и 2 соединителя ZWJ = 5 code points, одна графема.
      const family = '👨‍👩‍👧';
      expect(WorkoutText.characterCount(family), 5);
    });

    test('перенос строки — тоже символ', () {
      expect(WorkoutText.characterCount('a\nb'), 3);
      expect(WorkoutText.characterCount('a\r\nb'), 4);
    });
  });

  group('prepareResult', () {
    test('пробелы и переносы по краям обрезаются', () {
      expect(WorkoutText.prepareResult('  \n 5x5  \t\n'), '5x5');
    });

    test('внутри переносы строк, возврат каретки и табуляция остаются', () {
      expect(WorkoutText.prepareResult('раз\nдва\r\n\tтри'), 'раз\nдва\r\n\tтри');
    });

    test('прочие управляющие символы C0 убираются', () {
      expect(WorkoutText.prepareResult('a\u0000b\u0007c\u001Bd'), 'abcd');
      expect(WorkoutText.prepareResult('\u0000  текст  \u0007'), 'текст');
    });

    test('только пробелы и управляющие — пустая строка', () {
      expect(WorkoutText.prepareResult('   \n\t '), '');
      expect(WorkoutText.prepareResult('\u0000\u0001'), '');
    });

    test('эмодзи и составные символы не трогаются', () {
      const text = '5×5 💪 — «тяжело» 👨‍👩‍👧';
      expect(WorkoutText.prepareResult(text), text);
    });
  });

  group('isValidResult — от 1 до 1000 символов', () {
    test('пусто — нет, один символ — да', () {
      expect(WorkoutText.isValidResult(''), isFalse);
      expect(WorkoutText.isValidResult('a'), isTrue);
    });

    test('ровно 1000 — да, 1001 — нет', () {
      expect(WorkoutText.isValidResult('я' * 1000), isTrue);
      expect(WorkoutText.isValidResult('я' * 1001), isFalse);
    });

    test('эмодзи: 1000 штук (2000 единиц String.length) — да, 1001 — нет', () {
      expect(WorkoutText.isValidResult('💪' * 1000), isTrue);
      expect(WorkoutText.isValidResult('💪' * 1001), isFalse);
    });

    test('составные эмодзи считаются по code points: 200 семей = 1000, 201 — много', () {
      expect(WorkoutText.isValidResult('👨‍👩‍👧' * 200), isTrue);
      expect(WorkoutText.isValidResult('👨‍👩‍👧' * 201), isFalse);
    });

    test('константа лимита', () {
      expect(WorkoutText.maxResultLength, 1000);
    });
  });

  group('MaxCodePointsFormatter', () {
    const formatter = MaxCodePointsFormatter(5);

    TextEditingValue apply(String text, {int? caret}) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret ?? text.length),
      ),
    );

    test('в пределах лимита — без изменений', () {
      expect(apply('12345').text, '12345');
      expect(apply('').text, '');
    });

    test('вставка длиннее лимита обрезается до лимита', () {
      final result = apply('1234567890');

      expect(result.text, '12345');
      expect(result.selection, const TextSelection.collapsed(offset: 5));
    });

    test('считает code points: пять эмодзи помещаются, шестой — нет', () {
      expect(apply('💪💪💪💪💪').text, '💪💪💪💪💪');
      expect(apply('💪💪💪💪💪💪').text, '💪💪💪💪💪');
    });

    test('эмодзи не разрезается пополам при обрезке', () {
      final result = apply('abcd💪💪');

      expect(result.text, 'abcd💪');
      expect(result.text.runes.length, 5);
    });

    test('курсор не выходит за текст', () {
      final result = apply('1234567890', caret: 10);

      expect(result.selection.baseOffset, lessThanOrEqualTo(result.text.length));
    });

    test('лимит формы — 1000', () {
      const form = MaxCodePointsFormatter(WorkoutText.maxResultLength);
      final result = form.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: 'я' * 1200),
      );

      expect(result.text.runes.length, 1000);
    });
  });
}
