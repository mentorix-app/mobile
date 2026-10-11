import 'package:dio/dio.dart';
import 'package:mentorix_app/core/config/api_config.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: ApiConfig.baseUrl,
  // Без Content-Type: application/json сервер не читает тело: refresh ответит
  // 401, а logout — 204 без завершения сессии.
  contentType: Headers.jsonContentType,
  responseType: ResponseType.json,
  connectTimeout: ApiConfig.connectTimeout,
  receiveTimeout: ApiConfig.receiveTimeout,
  sendTimeout: ApiConfig.sendTimeout,
);

/// Клиент без перехватчиков: только refresh и повтор запросов внутри
/// [AuthInterceptor]. Токен сам не подставляет и сам себя не обновляет — иначе цикл.
Dio createPlainDio() => Dio(_baseOptions());

/// Основной клиент для всех запросов приложения: Bearer и обновление сессии
/// делает [AuthInterceptor]. Публичные эндпоинты (вход, logout) помечаются
/// `extra: {AuthInterceptor.skipAuthKey: true}` — перехватчик их не трогает.
Dio createApiDio({
  required Dio plainDio,
  required TokenStorage tokens,
  required SessionExpiredNotifier sessionExpired,
}) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    AuthInterceptor(
      tokens: tokens,
      plainDio: plainDio,
      sessionExpired: sessionExpired,
    ),
  );
  return dio;
}
