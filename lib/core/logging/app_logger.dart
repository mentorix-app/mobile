import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';

/// Сырой текст ошибок пользователю не показывается — только сюда.
///
/// Токены, тела запросов и заголовки в лог не попадают никогда.
///
/// В debug-сборке строки идут через [DebugLog] (`debugPrint`) — они видны в
/// консоли `flutter run`; в release — через `dart:developer`, как раньше.
abstract final class AppLogger {
  static void error(String message, Object error, [StackTrace? stackTrace]) {
    if (DebugLog.enabled) {
      DebugLog.write('mentorix', 'ERROR $message: $error');
      if (stackTrace != null) DebugLog.write('mentorix', '$stackTrace');
      return;
    }

    developer.log(
      message,
      name: 'mentorix',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Предупреждение о неверной конфигурации (например, плейсхолдер вместо
  /// реального значения): приложение работает, но функция недоступна.
  static void warning(String message) {
    if (DebugLog.enabled) {
      DebugLog.write('mentorix', 'WARNING $message');
      return;
    }

    developer.log(message, name: 'mentorix', level: 900);
  }

  /// Строка журнала запроса к API (см. `ApiLogInterceptor`). Только debug.
  static void http(String line) => DebugLog.write('mentorix.http', line);

  /// Логирует ошибку запроса без заголовков и тел: метод, путь, статус и
  /// `code` из ответа бэкенда.
  static void dioError(DioException e, [StackTrace? stackTrace]) {
    final options = e.requestOptions;
    final code = ApiErrorCodes.of(e.response);
    final line =
        '${options.method} ${options.path} -> '
        '${e.response?.statusCode ?? e.type.name}'
        '${code != null ? ' code=$code' : ''}';

    // В debug ту же строку уже написал `ApiLogInterceptor`.
    if (DebugLog.enabled) return;

    developer.log(
      line,
      name: 'mentorix.http',
      level: 900,
      stackTrace: stackTrace,
    );
  }
}
