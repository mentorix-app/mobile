import 'package:dio/dio.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/config/api_config.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/masked_talker_dio_logger.dart';
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

/// Клиент без перехватчиков авторизации: только refresh и повтор запросов
/// внутри [AuthInterceptor]. Токен сам не подставляет и сам себя не обновляет —
/// иначе цикл. В debug-сборке пишет запросы в Talker (с маскировкой секретов),
/// чтобы refresh был виден.
Dio createPlainDio() {
  final dio = Dio(_baseOptions());
  if (DebugLog.enabled) {
    dio.interceptors.add(MaskedTalkerDioLogger(talker: AppTalker.instance));
  }
  return dio;
}

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
  // После [AuthInterceptor]: к моменту записи заголовок Authorization уже
  // подставлен (в логе он виден как `***`). 401, который он обновил и повторил,
  // здесь не виден, но refresh и повтор пишет журнал [plainDio].
  if (DebugLog.enabled) {
    dio.interceptors.add(MaskedTalkerDioLogger(talker: AppTalker.instance));
  }
  return dio;
}
