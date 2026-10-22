import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/domain/workout_text.dart';

import '../../helpers/talker_capture.dart';

void main() {
  tearDown(() => DebugLog.debugModeOverride = null);

  group('optionalString / string', () {
    test('optionalString: пусто, пробелы, null, нет ключа, не строка — null', () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'k': null},
        {'k': ''},
        {'k': '   '},
        {'k': 5},
        {'k': <Object>[]},
      ]) {
        expect(JsonReading.optionalString(json, 'k'), isNull, reason: '$json');
      }
      expect(JsonReading.optionalString({'k': '  Тренер '}, 'k'), 'Тренер');
    });

    test('string: как есть, иначе пустая строка', () {
      expect(JsonReading.string({'k': ' a '}, 'k'), ' a ');
      expect(JsonReading.string({}, 'k'), '');
      expect(JsonReading.string({'k': null}, 'k'), '');
      expect(JsonReading.string({'k': 1}, 'k'), '');
    });
  });

  group('volume (sets, reps)', () {
    test('значения контракта сохраняются как есть', () {
      for (final value in ['3', '5/4', '8-12', '15']) {
        expect(JsonReading.volume({'sets': value}, 'sets'), value);
      }
    });

    test('нет ключа, null, пустая строка, пробелы — null', () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'sets': null},
        {'sets': ''},
        {'sets': '  '},
        {'sets': true},
        {'sets': <Object>[]},
      ]) {
        expect(JsonReading.volume(json, 'sets'), isNull, reason: '$json');
      }
    });

    test('число вопреки схеме превращается в строку', () {
      expect(JsonReading.volume({'sets': 5}, 'sets'), '5');
      expect(JsonReading.volume({'sets': 7.5}, 'sets'), '7.5');
    });

    test('содержимое не разбирается и не нормализуется', () {
      expect(JsonReading.volume({'reps': ' 8-12 '}, 'reps'), '8-12');
      expect(JsonReading.volume({'reps': 'abc'}, 'reps'), 'abc');
    });
  });

  group('integer / number / boolean / dateTime / object', () {
    test('integer: число, дробное обрезается, остальное — fallback', () {
      expect(JsonReading.integer({'n': 3}, 'n'), 3);
      expect(JsonReading.integer({'n': 3.9}, 'n'), 3);
      expect(JsonReading.integer({'n': '3'}, 'n'), 0);
      expect(JsonReading.integer({}, 'n', fallback: -1), -1);
      expect(JsonReading.integer({'n': null}, 'n'), 0);
    });

    test('number: double или null', () {
      expect(JsonReading.number({'p': 12.5}, 'p'), 12.5);
      expect(JsonReading.number({'p': 100}, 'p'), 100.0);
      expect(JsonReading.number({'p': 'x'}, 'p'), isNull);
    });

    test('boolean: только true', () {
      expect(JsonReading.boolean({'b': true}, 'b'), isTrue);
      expect(JsonReading.boolean({'b': 'true'}, 'b'), isFalse);
      expect(JsonReading.boolean({}, 'b'), isFalse);
    });

    test('dateTime: UTC, плохая строка и не строка — null', () {
      final date = JsonReading.dateTime(
        {'t': '2026-10-20T15:24:33.085477Z'},
        't',
      );

      expect(date, DateTime.utc(2026, 10, 20, 15, 24, 33, 85, 477));
      expect(date!.isUtc, isTrue);
      expect(JsonReading.dateTime({'t': 'вчера'}, 't'), isNull);
      expect(JsonReading.dateTime({'t': 5}, 't'), isNull);
      expect(JsonReading.dateTime({}, 't'), isNull);
    });

    test('object: объект или null', () {
      expect(JsonReading.object({'o': {'a': 1}}, 'o'), {'a': 1});
      expect(JsonReading.object({'o': null}, 'o'), isNull);
      expect(JsonReading.object({'o': []}, 'o'), isNull);
      expect(JsonReading.object({}, 'o'), isNull);
    });
  });

  group('objects', () {
    test('нет ключа, null, не список — пустой список', () {
      expect(JsonReading.objects({}, 'xs'), isEmpty);
      expect(JsonReading.objects({'xs': null}, 'xs'), isEmpty);
      expect(JsonReading.objects({'xs': {'a': 1}}, 'xs'), isEmpty);
    });

    test('элементы не объекты пропускаются, порядок сохраняется', () {
      final result = JsonReading.objects({
        'xs': [
          {'a': 1},
          'строка',
          null,
          5,
          {'a': 2},
        ],
      }, 'xs');

      expect(result, [
        {'a': 1},
        {'a': 2},
      ]);
    });

    test('пропуск пишется в debug-лог без содержимого элементов', () {
      JsonReading.objects({
        'blocks': ['секретная строка пользователя', 7],
      }, 'blocks');

      final messages = loggedMessages();
      expect(messages, hasLength(1));
      expect(
        messages.single,
        '[mentorix.workout] skipped blocks: 2 item(s) are not objects',
      );
      expect(messages.single, isNot(contains('секретная')));
    });

    test('в release лог молчит', () {
      DebugLog.debugModeOverride = false;

      JsonReading.objects({
        'blocks': [1],
      }, 'blocks');

      expect(loggedMessages(), isEmpty);
    });
  });

  group('userText / WorkoutText', () {
    test('переносы строк и табуляция остаются', () {
      expect(
        JsonReading.userText({'t': 'раз\nдва\r\n\tтри'}, 't'),
        'раз\nдва\r\n\tтри',
      );
    });

    test('прочие управляющие символы C0 убираются', () {
      expect(
        JsonReading.userText({'t': 'a\u0000b\u0007c\u001Bd\u000Be\u000Cf'}, 't'),
        'abcdef',
      );
    });

    test('обычный текст, эмодзи и кириллица не тронуты', () {
      const text = 'Сделал 3×10 💪, «тяжело» — 👨‍👩‍👧';

      expect(WorkoutText.stripControlChars(text), text);
    });

    test('нет значения — пустая строка', () {
      expect(JsonReading.userText({}, 't'), '');
      expect(JsonReading.userText({'t': null}, 't'), '');
    });
  });
}
