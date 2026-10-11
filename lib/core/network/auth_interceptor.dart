import 'package:dio/dio.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';

/// Подставляет Bearer и обновляет сессию.
///
/// * Токен почти истёк — обновляется **до** запроса.
/// * 401 — один refresh на всех: запросы, получившие 401 со старым токеном,
///   после чужого refresh просто повторяются с новым, без второго refresh.
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
    DateTime Function()? now,
  }) : _tokens = tokens,
       _plainDio = plainDio,
       _sessionExpired = sessionExpired,
       _now = now ?? DateTime.now;

  /// Ключ в `RequestOptions.extra`: запрос уже повторялся, повторять нельзя.
  static const retriedKey = 'auth_retried';

  static const refreshPath = '/auth/refresh';

  final TokenStorage _tokens;
  final Dio _plainDio;
  final SessionExpiredNotifier _sessionExpired;

  /// За сколько до `expires_at` токен считается истёкшим.
  final Duration refreshLeeway;
  final DateTime Function() _now;

  Future<AuthTokens>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      var accessToken = await _tokens.readAccessToken();

      if (accessToken != null && await _isAboutToExpire()) {
        accessToken = (await _refreshShared()).accessToken;
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
    } on DioException catch (e) {
      handler.reject(e.copyWith(requestOptions: options));
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;

    if (err.response?.statusCode != 401 || options.extra[retriedKey] == true) {
      return handler.next(err);
    }

    try {
      final sent = options.headers['Authorization'];
      final current = await _tokens.readAccessToken();

      // Кто-то уже обновил сессию, пока этот запрос был в пути.
      final accessToken = current != null && sent != 'Bearer $current'
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

  Future<bool> _isAboutToExpire() async {
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
        refreshPath,
        data: {'refresh_token': refreshToken},
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
