import 'package:dio/dio.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';

/// Лог приложения поверх [AppTalker]. Интерфейс прежний, внутри — Talker.
///
/// Работает только в debug-сборке; в release все методы ничего не делают.
/// Токены, тела запросов и заголовки сюда не передаются: запросы к API пишет
/// `MaskedTalkerDioLogger` с маскировкой секретов.
abstract final class AppLogger {
  static void error(String message, Object error, [StackTrace? stackTrace]) {
    if (!DebugLog.enabled) return;
    AppTalker.instance.error(message, error, stackTrace);
  }

  /// Предупреждение о неверной конфигурации (например, плейсхолдер вместо
  /// реального значения): приложение работает, но функция недоступна.
  static void warning(String message) {
    if (!DebugLog.enabled) return;
    AppTalker.instance.warning(message);
  }

  /// Произвольная строка журнала запроса. Сами запросы пишет
  /// `MaskedTalkerDioLogger`.
  static void http(String line) => DebugLog.write('mentorix.http', line);

  /// Ошибка запроса. В debug её уже записал `MaskedTalkerDioLogger` — вместе
  /// со статусом, `code`, временем, заголовками и телами (замаскированными),
  /// поэтому здесь второй строки нет. Метод оставлен для совместимости.
  static void dioError(DioException e, [StackTrace? stackTrace]) {}
}
