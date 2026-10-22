import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/features/workout/domain/workout_text.dart';

/// Терпимое чтение JSON ответов API (`CLAUDE.md`, раздел 5): неизвестное поле
/// или `null` там, где ждали значение, не роняют экран.
///
/// Правила одни на все модели фичи; значения по умолчанию — пустая строка,
/// `null` или `0`, а не исключение. Исключение бросают только модели и только
/// для идентификатора, без которого объект бессмыслен.
abstract final class JsonReading {
  static const _tag = 'mentorix.workout';

  /// Непустая строка после обрезки пробелов или `null`: ключа нет, `null`,
  /// пустая строка и значение другого типа дают `null`.
  static String? optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Строка как есть либо `''`, если ключа нет или тип не тот.
  static String string(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String ? value : '';
  }

  /// Текст пользователя или тренера (`result_text`, ответ): без управляющих
  /// символов C0, переносы строк сохраняются. Нет значения — `''`.
  static String userText(Map<String, dynamic> json, String key) =>
      WorkoutText.stripControlChars(string(json, key));

  /// Объём упражнения (`sets`, `reps`): строка вида `3`, `5/4`, `8-12`.
  /// Ключа нет, `null`, пустая строка или пробелы — `null`. Число (вопреки
  /// схеме) превращается в строку. Содержимое не разбирается.
  static String? volume(Map<String, dynamic> json, String key) {
    final value = json[key];
    return switch (value) {
      String() => value.trim().isEmpty ? null : value.trim(),
      num() => '$value',
      _ => null,
    };
  }

  /// Целое: `int`, дробное число обрезается; всё остальное — [fallback].
  static int integer(Map<String, dynamic> json, String key, {int fallback = 0}) {
    final value = json[key];
    return value is num ? value.toInt() : fallback;
  }

  static double? number(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is num ? value.toDouble() : null;
  }

  static bool boolean(Map<String, dynamic> json, String key) =>
      json[key] == true;

  /// Момент времени в UTC; нет ключа или строка не разобралась — `null`.
  static DateTime? dateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }

  /// Вложенный объект или `null` (ключа нет, `null`, не объект).
  static Map<String, dynamic>? object(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is Map<String, dynamic> ? value : null;
  }

  /// Список объектов. Ключа нет, `null` или не список — пустой список. Элементы,
  /// которые не объекты, пропускаются; сколько их было, пишется в debug-лог
  /// (`[mentorix.workout] skipped …`), весь экран из-за них не падает.
  static List<Map<String, dynamic>> objects(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! List) return const [];

    final result = <Map<String, dynamic>>[];
    var skipped = 0;
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        result.add(item);
      } else {
        skipped++;
      }
    }
    if (skipped > 0) skip(key, '$skipped item(s) are not objects');
    return result;
  }

  /// Как [objects], но по возрастанию `sort_order`. Порядок стабильный:
  /// элементы с равным или отсутствующим `sort_order` остаются как пришли
  /// (`List.sort` в Dart не гарантирует стабильность, поэтому сравниваем и
  /// исходную позицию).
  static List<Map<String, dynamic>> objectsBySortOrder(
    Map<String, dynamic> json,
    String key,
  ) {
    final items = objects(json, key);
    final order = List<int>.generate(items.length, (i) => i)
      ..sort((a, b) {
        final byOrder = integer(items[a], 'sort_order').compareTo(
          integer(items[b], 'sort_order'),
        );
        return byOrder != 0 ? byOrder : a.compareTo(b);
      });
    return [for (final i in order) items[i]];
  }

  /// Запись о пропущенном элементе. Содержимое элемента не пишется: в нём может
  /// быть текст пользователя.
  static void skip(String where, String reason) =>
      DebugLog.write(_tag, 'skipped $where: $reason');
}
