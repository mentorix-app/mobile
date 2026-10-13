import 'package:flutter/foundation.dart';

/// Диагностика только для debug-сборки: всё, что пишется или показывается через
/// неё, в release отсутствует.
///
/// Пишет через [debugPrint], а не `dart:developer`: эти строки видны в консоли
/// `flutter run` и в Debug Console VS Code без настройки фильтров.
///
/// Правила: токены, пароли и тела запросов сюда не попадают. Допустимы
/// персональные данные, которые нужны для отладки конкретного сценария (имя из
/// Apple), — но только здесь, а не в `AppLogger`, который работает и в release.
abstract final class DebugLog {
  /// `false` в release (константа `kDebugMode`): вызовы и данные для них
  /// отбрасываются компилятором.
  static bool get enabled => debugModeOverride ?? kDebugMode;

  /// Только для тестов: имитирует release (`false`) или debug (`true`), потому
  /// что `kDebugMode` — константа и в тестах всегда `true`.
  @visibleForTesting
  static bool? debugModeOverride;

  static void write(String tag, String message) {
    if (!enabled) return;
    debugPrint('[$tag] $message');
  }

  /// `yes` / `no` — для полей, значения которых писать нельзя.
  static String yesNo(Object? value) {
    final present = value is String ? value.isNotEmpty : value != null;
    return present ? 'yes' : 'no';
  }

  /// Значение в кавычках или `null`, чтобы пустая строка не терялась.
  static String quoted(String? value) => value == null ? 'null' : '"$value"';
}
