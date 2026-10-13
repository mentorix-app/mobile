import 'package:dio/dio.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';

/// Одна строка на каждый запрос к API: время (UTC), метод, путь, статус и `code`
/// из тела ответа. Именно это просит бэкенд-разработчик, чтобы сопоставлять
/// запросы приложения со своими логами.
///
/// Тела, заголовки и токены в строку не попадают. Подключается только в
/// debug-сборке (`createApiDio`/`createPlainDio`).
class ApiLogInterceptor extends Interceptor {
  ApiLogInterceptor({void Function(String line)? sink, DateTime Function()? now})
    : _sink = sink ?? AppLogger.http,
      _now = now ?? DateTime.now;

  final void Function(String line) _sink;
  final DateTime Function() _now;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _write(response.requestOptions, response.statusCode?.toString(), null);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    _write(
      err.requestOptions,
      // Ответа не было (нет связи, таймаут) — вместо статуса тип ошибки.
      status?.toString() ?? err.type.name,
      ApiErrorCodes.of(err.response),
    );
    handler.next(err);
  }

  void _write(RequestOptions options, String? status, String? code) {
    final time = _now().toUtc().toIso8601String();
    _sink(
      '$time ${options.method} ${options.path} ${status ?? '-'}'
      '${code != null ? ' code=$code' : ''}',
    );
  }
}
