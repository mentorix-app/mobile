import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';

/// Сырой текст ошибок пользователю не показывается — только сюда.
///
/// Токены, тела запросов и заголовки в лог не попадают никогда.
abstract final class AppLogger {
  static void error(String message, Object error, [StackTrace? stackTrace]) {
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
    developer.log(message, name: 'mentorix', level: 900);
  }

  /// Строка журнала запроса к API (см. `ApiLogInterceptor`).
  static void http(String line) {
    developer.log(line, name: 'mentorix.http', level: 500);
  }

  /// Логирует ошибку запроса без заголовков и тел: метод, путь, статус и
  /// `code` из ответа бэкенда.
  static void dioError(DioException e, [StackTrace? stackTrace]) {
    final options = e.requestOptions;
    final code = ApiErrorCodes.of(e.response);

    developer.log(
      '${options.method} ${options.path} -> '
      '${e.response?.statusCode ?? e.type.name}'
      '${code != null ? ' code=$code' : ''}',
      name: 'mentorix.http',
      level: 900,
      stackTrace: stackTrace,
    );
  }
}
