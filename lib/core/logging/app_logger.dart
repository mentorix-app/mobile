import 'dart:developer' as developer;

import 'package:dio/dio.dart';

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

  /// Логирует ошибку запроса без заголовков и тел: метод, путь, статус,
  /// `message` из ответа бэкенда.
  static void dioError(DioException e, [StackTrace? stackTrace]) {
    final options = e.requestOptions;
    final data = e.response?.data;
    final backendMessage = data is Map ? data['message'] : null;

    developer.log(
      '${options.method} ${options.path} -> '
      '${e.response?.statusCode ?? e.type.name}'
      '${backendMessage != null ? ' "$backendMessage"' : ''}',
      name: 'mentorix.http',
      level: 900,
      stackTrace: stackTrace,
    );
  }
}
