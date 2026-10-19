import 'package:dio/dio.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/secret_masker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// [TalkerDioLogger] с обязательной маскировкой секретов.
///
/// Пишет метод, путь, статус, время ответа, заголовки и тела запроса и ответа.
/// Заголовки видны на экране логов; в консоль их не печатает
/// `ConsoleLoggerFormatter`.
/// Секреты ([SecretMasker]) подменяются на `***` **до** того, как запись
/// попадёт в Talker, поэтому их нет ни в консоли, ни в истории, ни на экране
/// логов.
///
/// Запись хранит ссылки на объекты запроса и ответа и формирует текст позже, а
/// другие перехватчики (Bearer) меняют те же заголовки. Поэтому в Talker
/// уходит замаскированная **копия**, а настоящие объекты едут по цепочке
/// без изменений.
class MaskedTalkerDioLogger extends TalkerDioLogger {
  MaskedTalkerDioLogger({required Talker talker})
    : super(
        talker: talker,
        settings: const TalkerDioLoggerSettings(
          printRequestHeaders: true,
          printResponseHeaders: true,
          printErrorHeaders: true,
          printRequestData: true,
          printResponseData: true,
          printErrorData: true,
          printResponseTime: true,
        ),
      );

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Время ответа считается от метки в `extra` исходного запроса.
    options.extra[TalkerDioLogger.kDioLogsTimeStampKey] =
        DateTime.now().millisecondsSinceEpoch;

    // Настоящий handler в super не отдаём: он бы передал дальше копию с `***`.
    super.onRequest(_maskOptions(options), _SinkRequestHandler());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    super.onResponse(_maskResponse(response), _SinkResponseHandler());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;

    super.onError(
      err.copyWith(
        requestOptions: _maskOptions(err.requestOptions),
        response: response == null ? null : _maskResponse(response),
      ),
      _SinkErrorHandler(),
    );
    handler.next(err);
  }

  RequestOptions _maskOptions(RequestOptions options) {
    return options.copyWith(
      headers: SecretMasker.maskHeaders(options.headers),
      data: SecretMasker.maskBody(
        options.data,
        // Одноразовый код привязки Telegram: в теле запроса он секрет.
        maskCode: options.path == ApiEndpoints.authTelegramLink,
      ),
    );
  }

  Response<dynamic> _maskResponse(Response<dynamic> response) {
    return Response<dynamic>(
      requestOptions: _maskOptions(response.requestOptions),
      data: SecretMasker.maskBody(response.data),
      headers: Headers.fromMap({
        for (final entry in response.headers.map.entries)
          entry.key: SecretMasker.isSecretHeader(entry.key)
              ? [SecretMasker.mask]
              : entry.value,
      }),
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      extra: response.extra,
    );
  }
}

// Обработчики-«пустышки» для super: то, что он в них передаст, никуда не уходит.
// Ошибку dio завершает как ошибку `future`, и без слушателя она стала бы
// необработанной, поэтому каждый глушит её у себя.

class _SinkRequestHandler extends RequestInterceptorHandler {
  _SinkRequestHandler() {
    future.ignore();
  }
}

class _SinkResponseHandler extends ResponseInterceptorHandler {
  _SinkResponseHandler() {
    future.ignore();
  }
}

class _SinkErrorHandler extends ErrorInterceptorHandler {
  _SinkErrorHandler() {
    future.ignore();
  }
}
