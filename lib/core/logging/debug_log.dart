import 'package:flutter/foundation.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';

/// Диагностика только для debug-сборки: всё, что пишется или показывается через
/// неё, в release отсутствует.
///
/// Пишет в [AppTalker]: строки видны в консоли `flutter run`, в Debug Console
/// VS Code и на экране логов (долгое нажатие на заголовок профиля). Тег
/// остаётся в тексте: `[mentorix.apple] …`, `[mentorix.delete] …`.
///
/// Правила: токены, пароли и тела запросов сюда не попадают (тела запросов к
/// API пишет `MaskedTalkerDioLogger` с маскировкой секретов). Допустимы
/// персональные данные, которые нужны для отладки конкретного сценария (имя из
/// Apple), — но только здесь.
abstract final class DebugLog {
  /// `false` в release: `kDebugMode` — константа, поэтому вызовы и всё, что за
  /// ними, отбрасывается компилятором.
  static bool get enabled => kDebugMode && (debugModeOverride ?? true);

  /// Только для тестов: `false` имитирует release, потому что `kDebugMode` —
  /// константа и в тестах всегда `true`.
  @visibleForTesting
  static bool? debugModeOverride;

  static void write(String tag, String message) {
    if (!enabled) return;
    AppTalker.instance.debug('[$tag] $message');
  }

  /// `yes` / `no` — для полей, значения которых писать нельзя.
  static String yesNo(Object? value) {
    final present = value is String ? value.isNotEmpty : value != null;
    return present ? 'yes' : 'no';
  }

  /// Значение в кавычках или `null`, чтобы пустая строка не терялась.
  static String quoted(String? value) => value == null ? 'null' : '"$value"';
}
