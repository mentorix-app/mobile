import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';

/// Подставляет Bearer и обновляет сессию.
///
/// * Запрос с `extra[skipAuthKey] == true` (публичные эндпоинты: вход, refresh,
///   logout) проходит мимо перехватчика целиком: без Bearer, без упреждающего
///   refresh, без обработки 401. Флаг ставит датасорс, по путям перехватчик
///   не угадывает.
/// * Токен почти истёк — обновляется **до** запроса. Если это обновление упало
///   не с 401 (сеть, 5xx, 429), запрос всё равно уходит с текущим токеном:
///   он ещё действует, а 401 разберёт [onError]. Новые попытки упреждающего
///   refresh после неудачи — не раньше чем через 30 секунд (сеть, 5xx); при 429 —
///   через `Retry-After` из ответа или через 5 минут.
/// * 401 — один refresh на всех: запросы, получившие 401 со старым токеном,
///   после чужого refresh просто повторяются с новым, без второго refresh.
/// * 401 с `code: invalid_id_token` (токен Apple из тела запроса, не Bearer)
///   не обновляет сессию и не повторяется.
/// * Повтор идёт через [plainDio] (без перехватчиков) и только один раз.
/// * Refresh вернул 401 — токены очищены, [SessionExpiredNotifier] оповещён.
///
/// `QueuedInterceptor` выстраивает обработку ошибок в очередь, поэтому обновление
/// не запускается параллельно ни из-за двух 401, ни из-за 401 и упреждающего
/// refresh — для последнего служит общий [_refreshing].
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage tokens,
    required Dio plainDio,
    required SessionExpiredNotifier sessionExpired,
    this.refreshLeeway = const Duration(seconds: 60),
    this.proactiveRefreshCooldown = const Duration(seconds: 30),
    this.rateLimitedCooldown = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _tokens = tokens,
       _plainDio = plainDio,
       _sessionExpired = sessionExpired,
       _now = now ?? DateTime.now;

  /// Ключ в `RequestOptions.extra`: запрос публичный, перехватчик его не трогает.
  static const skipAuthKey = 'skipAuth';

  /// Ключ в `RequestOptions.extra`: запрос уже повторялся, повторять нельзя.
  static const retriedKey = 'auth_retried';

  final TokenStorage _tokens;
  final Dio _plainDio;
  final SessionExpiredNotifier _sessionExpired;

  /// За сколько до `expires_at` токен считается истёкшим.
  final Duration refreshLeeway;

  /// После неудачного упреждающего refresh (не 401) следующие запросы не пытаются
  /// обновлять токен это время. Иначе при пропавшей связи каждый запрос из очереди
  /// ждал бы свой таймаут refresh. Для сети и 5xx.
  final Duration proactiveRefreshCooldown;

  /// То же для 429, если в ответе нет `Retry-After`: лимит refresh — десятки
  /// попыток за 15 минут, повторять через 30 секунд только тратит его.
  final Duration rateLimitedCooldown;
  final DateTime Function() _now;

  Future<AuthTokens>? _refreshing;
  DateTime? _proactiveRefreshRetryAfter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] == true) return handler.next(options);

    try {
      var accessToken = await _tokens.readAccessToken();

      if (accessToken != null && await _shouldRefreshBeforeRequest()) {
        try {
          accessToken = (await _refreshShared()).accessToken;
        } on DioException catch (e) {
          // Сеть, 5xx или 429: токен ещё действует (refresh начинается за
          // refreshLeeway до истечения). Шлём с текущим, 401 разберёт onError.
          _proactiveRefreshRetryAfter = _now().add(_cooldownAfter(e));
        }
      }

      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
      handler.next(options);
    } on SessionExpiredException {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const SessionExpiredException(),
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;

    if (options.extra[skipAuthKey] == true ||
        err.response?.statusCode != 401 ||
        options.extra[retriedKey] == true) {
      return handler.next(err);
    }

    // 401 `invalid_id_token` — не истёкший access-токен, а отказ в токене
    // Apple из тела запроса (удаление аккаунта). Refresh не поможет, а повтор
    // потратил бы одноразовый authorization_code.
    if (ApiErrorCodes.of(err.response) == ApiErrorCodes.invalidIdToken) {
      return handler.next(err);
    }

    try {
      final sent = options.headers['Authorization'];
      final current = await _tokens.readAccessToken();

      // Кто-то уже обновил сессию, пока этот запрос был в пути.
      final alreadyRefreshed = current != null && sent != 'Bearer $current';

      // Только debug: почему запрос повторяется. Значения токенов не пишутся.
      AppLogger.http(
        '401 на ${options.method} ${options.path} → '
        '${alreadyRefreshed ? 'повтор с уже обновлённым токеном' : 'refresh'}',
      );

      final accessToken = alreadyRefreshed
          ? current
          : (await _refreshShared()).accessToken;

      final response = await _plainDio.fetch<dynamic>(
        options.copyWith(
          headers: {...options.headers, 'Authorization': 'Bearer $accessToken'},
          extra: {...options.extra, retriedKey: true},
        ),
      );
      handler.resolve(response);
    } on SessionExpiredException {
      handler.next(
        DioException(
          requestOptions: options,
          response: err.response,
          type: DioExceptionType.badResponse,
          error: const SessionExpiredException(),
        ),
      );
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// 429 — по `Retry-After` из ответа (секунды или HTTP-дата), иначе
  /// [rateLimitedCooldown]; сеть и 5xx — [proactiveRefreshCooldown].
  Duration _cooldownAfter(DioException e) {
    if (e.response?.statusCode != 429) return proactiveRefreshCooldown;
    return _retryAfter(e.response) ?? rateLimitedCooldown;
  }

  Duration? _retryAfter(Response<dynamic>? response) {
    final raw = response?.headers.value('retry-after')?.trim();
    if (raw == null || raw.isEmpty) return null;

    final seconds = int.tryParse(raw);
    if (seconds != null) {
      return seconds < 0 ? null : Duration(seconds: seconds);
    }

    try {
      final until = HttpDate.parse(raw).difference(_now().toUtc());
      return until.isNegative ? Duration.zero : until;
    } on Object {
      return null;
    }
  }

  Future<bool> _shouldRefreshBeforeRequest() async {
    final retryAfter = _proactiveRefreshRetryAfter;
    if (retryAfter != null && _now().isBefore(retryAfter)) return false;

    final expiresAt = await _tokens.readExpiresAt();
    if (expiresAt == null) return false;
    return !_now().toUtc().isBefore(expiresAt.subtract(refreshLeeway));
  }

  /// Один общий Future на всех, кому нужен refresh.
  Future<AuthTokens> _refreshShared() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;

    final future = _refresh().whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  Future<AuthTokens> _refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) {
      await _expireSession();
      throw const SessionExpiredException();
    }

    final Response<Map<String, dynamic>> response;
    try {
      response = await _plainDio.post<Map<String, dynamic>>(
        ApiEndpoints.authRefresh,
        data: {'refresh_token': refreshToken},
        // Публичный эндпоинт: сам refresh перехватчик не обрабатывает.
        options: Options(extra: {skipAuthKey: true}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _expireSession();
        throw const SessionExpiredException();
      }
      // 429, 5xx и обрыв связи сессию не убивают: токены остаются на месте.
      rethrow;
    }

    final AuthTokens tokens;
    try {
      tokens = AuthTokens.fromJson(response.data ?? const {});
    } on FormatException catch (e) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: e,
      );
    }

    // Старый refresh-токен уже недействителен: сохраняем новый сразу.
    await _tokens.save(tokens);
    return tokens;
  }

  Future<void> _expireSession() async {
    final hadSession = await _tokens.hasAnyToken();
    await _tokens.clear();
    // Параллельные запросы получат 401 по одному: оповещаем один раз.
    if (hadSession) _sessionExpired.notify();
  }
}
