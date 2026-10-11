import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http_adapter.dart';

const _baseUrl = 'https://api.test';

void main() {
  late TokenStorage tokens;
  late SessionExpiredNotifier notifier;
  late FakeHttpAdapter adapter;
  late Dio plainDio;
  late Dio apiDio;
  late int sessionExpiredEvents;
  late StreamSubscription<void> subscription;

  /// Ответы сервера: `/auth/refresh` отдаёт [refreshResponder], остальные пути —
  /// 200 только с актуальным токеном, иначе 401.
  void setUpClients({
    required Future<ResponseBody> Function(RequestOptions) refreshResponder,
    String validAccessToken = 'new-access',
    DateTime Function()? now,
    Map<String, FakeResponder> routes = const {},
  }) {
    adapter = FakeHttpAdapter((options) async {
      if (options.path == ApiEndpoints.authRefresh) return refreshResponder(options);
      final route = routes[options.path];
      if (route != null) return route(options);

      // Даём запросам «долететь» параллельно.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final authorized =
          options.headers['Authorization'] == 'Bearer $validAccessToken';
      return authorized
          ? jsonBody({'ok': true})
          : jsonBody({'message': 'unauthorized'}, status: 401);
    });

    BaseOptions baseOptions() => BaseOptions(
      baseUrl: _baseUrl,
      contentType: Headers.jsonContentType,
    );

    plainDio = Dio(baseOptions())..httpClientAdapter = adapter;
    apiDio = Dio(baseOptions())
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          tokens: tokens,
          plainDio: plainDio,
          sessionExpired: notifier,
          now: now,
        ),
      );
  }

  Future<void> signedInWith({
    String access = 'old-access',
    String refresh = 'old-refresh',
    DateTime? expiresAt,
  }) {
    return tokens.save(
      AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        userId: 'user-1',
        expiresAt: expiresAt,
      ),
    );
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    tokens = TokenStorage(
      const FlutterSecureStorage(),
      await SharedPreferences.getInstance(),
    );
    notifier = SessionExpiredNotifier();
    sessionExpiredEvents = 0;
    subscription = notifier.stream.listen((_) => sessionExpiredEvents++);
  });

  tearDown(() async {
    await subscription.cancel();
    await notifier.dispose();
  });

  group('401 → refresh', () {
    test(
      'три параллельных запроса: refresh ровно один, все три повторены '
      'с новым токеном',
      () async {
        setUpClients(
          refreshResponder: (options) async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return jsonBody(tokenJson());
          },
        );
        await signedInWith();

        final responses = await Future.wait([
          apiDio.get<Object?>('/a'),
          apiDio.get<Object?>('/b'),
          apiDio.get<Object?>('/c'),
        ]);

        expect(responses.map((r) => r.statusCode), [200, 200, 200]);
        expect(
          adapter.requestsTo(ApiEndpoints.authRefresh),
          hasLength(1),
          reason: 'параллельные 401 не должны запускать несколько refresh',
        );

        for (final path in ['/a', '/b', '/c']) {
          final sent = adapter.requestsTo(path).toList();
          expect(sent, hasLength(2), reason: '$path: первая попытка и повтор');
          expect(sent.first.headers['Authorization'], 'Bearer old-access');
          expect(sent.last.headers['Authorization'], 'Bearer new-access');
        }

        // Новый refresh-токен сохранён сразу, старый не остался.
        expect(await tokens.readRefreshToken(), 'new-refresh');
        expect(await tokens.readAccessToken(), 'new-access');
        expect(sessionExpiredEvents, 0);
      },
    );

    test('refresh отправляется в JSON с refresh_token', () async {
      setUpClients(refreshResponder: (_) async => jsonBody(tokenJson()));
      await signedInWith();

      await apiDio.get<Object?>('/a');

      final refresh = adapter.requestsTo(ApiEndpoints.authRefresh).single;
      expect(refresh.data, {'refresh_token': 'old-refresh'});
      expect(refresh.contentType, Headers.jsonContentType);
    });

    test('refresh вернул 401: токены очищены, сессия завершена', () async {
      setUpClients(
        refreshResponder: (options) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return jsonBody({'message': 'invalid refresh token'}, status: 401);
        },
      );
      await signedInWith();

      final results = await Future.wait([
        apiDio.get<Object?>('/a').then<Object?>((r) => r, onError: (e) => e),
        apiDio.get<Object?>('/b').then<Object?>((r) => r, onError: (e) => e),
        apiDio.get<Object?>('/c').then<Object?>((r) => r, onError: (e) => e),
      ]);

      for (final result in results) {
        expect(result, isA<DioException>());
        expect(
          (result as DioException).error,
          isA<SessionExpiredException>(),
        );
      }

      expect(await tokens.readAccessToken(), isNull);
      expect(await tokens.readRefreshToken(), isNull);
      expect(await tokens.readUserId(), isNull);
      expect(adapter.requestsTo(ApiEndpoints.authRefresh), hasLength(1));

      await Future<void>.delayed(Duration.zero);
      expect(
        sessionExpiredEvents,
        1,
        reason: 'о конце сессии сообщаем один раз, не по разу на запрос',
      );
    });

    test('повтор делается один раз: 401 после refresh не зацикливается', () async {
      // Сервер принимает только токен, которого у нас никогда не будет.
      setUpClients(
        refreshResponder: (_) async => jsonBody(tokenJson()),
        validAccessToken: 'never-issued',
      );
      await signedInWith();

      await expectLater(
        apiDio.get<Object?>('/a'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );

      expect(adapter.requestsTo(ApiEndpoints.authRefresh), hasLength(1));
      expect(adapter.requestsTo('/a'), hasLength(2));
      // Токены остаются: конец сессии определяет только 401 на refresh.
      expect(await tokens.readRefreshToken(), 'new-refresh');
      expect(sessionExpiredEvents, 0);
    });

    test(
      'refresh не удался по сети или 5xx: токены не трогаем, сессию не завершаем',
      () async {
        setUpClients(
          refreshResponder: (_) async =>
              jsonBody({'message': 'boom'}, status: 500),
        );
        await signedInWith();

        await expectLater(
          apiDio.get<Object?>('/a'),
          throwsA(isA<DioException>()),
        );

        expect(await tokens.readRefreshToken(), 'old-refresh');
        expect(sessionExpiredEvents, 0);
      },
    );

    test('429 на refresh не повторяется автоматически', () async {
      setUpClients(
        refreshResponder: (_) async =>
            jsonBody({'message': 'slow down'}, status: 429),
      );
      await signedInWith();

      await expectLater(
        apiDio.get<Object?>('/a'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            429,
          ),
        ),
      );

      expect(adapter.requestsTo(ApiEndpoints.authRefresh), hasLength(1));
      expect(await tokens.readRefreshToken(), 'old-refresh');
    });
  });

  group('упреждающий refresh', () {
    test('токен почти истёк: обновляем до запроса', () async {
      final now = DateTime.utc(2030, 1, 1, 12);
      setUpClients(
        refreshResponder: (_) async => jsonBody(tokenJson()),
        now: () => now,
      );
      // Истекает через 30 секунд — меньше запаса в 60 секунд.
      await signedInWith(expiresAt: now.add(const Duration(seconds: 30)));

      final response = await apiDio.get<Object?>('/a');

      expect(response.statusCode, 200);
      expect(adapter.requestsTo(ApiEndpoints.authRefresh), hasLength(1));

      final sent = adapter.requestsTo('/a').toList();
      expect(sent, hasLength(1), reason: 'старый токен не отправлялся вовсе');
      expect(sent.single.headers['Authorization'], 'Bearer new-access');
    });

    test('токен свежий: refresh не нужен', () async {
      final now = DateTime.utc(2030, 1, 1, 12);
      setUpClients(
        refreshResponder: (_) async => jsonBody(tokenJson()),
        validAccessToken: 'old-access',
        now: () => now,
      );
      await signedInWith(expiresAt: now.add(const Duration(minutes: 10)));

      final response = await apiDio.get<Object?>('/a');

      expect(response.statusCode, 200);
      expect(adapter.requestsTo(ApiEndpoints.authRefresh), isEmpty);
    });
  });

  group('упреждающий refresh не удался не по 401', () {
    final now = DateTime.utc(2030, 1, 1, 12);

    Future<ResponseBody> connectionLost(RequestOptions options) async =>
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );

    Future<ResponseBody> serverError(RequestOptions _) async =>
        jsonBody({'message': 'boom'}, status: 500);

    Future<ResponseBody> tooManyRequests(RequestOptions _) async =>
        jsonBody({'message': 'slow down'}, status: 429);

    final failures = {
      'обрыв связи': connectionLost,
      '5xx': serverError,
      '429': tooManyRequests,
    };

    for (final entry in failures.entries) {
      test('${entry.key}: запрос всё равно уходит со старым токеном', () async {
        setUpClients(
          refreshResponder: entry.value,
          validAccessToken: 'old-access',
          now: () => now,
        );
        // Истекает через 30 секунд — внутри запаса в 60 секунд, но ещё действует.
        await signedInWith(expiresAt: now.add(const Duration(seconds: 30)));

        final response = await apiDio.get<Object?>('/a');

        expect(response.statusCode, 200);
        expect(adapter.requestsTo(ApiEndpoints.authRefresh), hasLength(1));

        final sent = adapter.requestsTo('/a').single;
        expect(sent.headers['Authorization'], 'Bearer old-access');

        // Сессия цела: токены на месте, о конце сессии не сообщали.
        expect(await tokens.readAccessToken(), 'old-access');
        expect(await tokens.readRefreshToken(), 'old-refresh');
        expect(sessionExpiredEvents, 0);
      });
    }

    test('после неудачи следующие запросы не ждут новый refresh (пауза)', () async {
      setUpClients(
        refreshResponder: connectionLost,
        validAccessToken: 'old-access',
        now: () => now,
      );
      await signedInWith(expiresAt: now.add(const Duration(seconds: 30)));

      await apiDio.get<Object?>('/a');
      await apiDio.get<Object?>('/b');
      await apiDio.get<Object?>('/c');

      expect(
        adapter.requestsTo(ApiEndpoints.authRefresh),
        hasLength(1),
        reason: 'без паузы каждый запрос очереди ждал бы таймаут refresh',
      );
      expect(adapter.requestsTo('/c').single.headers['Authorization'],
          'Bearer old-access');
    });

    test('если старый токен всё же не принят — обычная обработка 401', () async {
      // Первый refresh падает по сети, а сервер уже не принимает старый токен:
      // сработает onError, и второй refresh (после паузы это уже реактивный
      // путь) обновит сессию.
      var refreshCalls = 0;
      setUpClients(
        refreshResponder: (options) async {
          refreshCalls++;
          if (refreshCalls == 1) return connectionLost(options);
          return jsonBody(tokenJson());
        },
        now: () => now,
      );
      await signedInWith(expiresAt: now.add(const Duration(seconds: 30)));

      final response = await apiDio.get<Object?>('/a');

      expect(response.statusCode, 200);
      expect(refreshCalls, 2);
      final sent = adapter.requestsTo('/a').toList();
      expect(sent.first.headers['Authorization'], 'Bearer old-access');
      expect(sent.last.headers['Authorization'], 'Bearer new-access');
      expect(await tokens.readRefreshToken(), 'new-refresh');
    });

    test('401 на упреждающем refresh: запрос отклонён, сессия завершена', () async {
      setUpClients(
        refreshResponder: (_) async =>
            jsonBody({'message': 'invalid refresh token'}, status: 401),
        now: () => now,
      );
      await signedInWith(expiresAt: now.add(const Duration(seconds: 30)));

      await expectLater(
        apiDio.get<Object?>('/a'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<SessionExpiredException>(),
          ),
        ),
      );

      expect(adapter.requestsTo('/a'), isEmpty, reason: 'до сервера не дошёл');
      expect(await tokens.readRefreshToken(), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(sessionExpiredEvents, 1);
    });
  });

  group('публичные эндпоинты (skipAuth)', () {
    final now = DateTime.utc(2030, 1, 1, 12);

    test(
      '401 от /auth/google: refresh не вызывается, ошибка — «вход не удался»',
      () async {
        setUpClients(
          refreshResponder: (_) async => jsonBody(tokenJson()),
          routes: {
            ApiEndpoints.authGoogle: (_) async =>
                jsonBody({'message': 'invalid id_token'}, status: 401),
          },
        );
        await signedInWith();

        await expectLater(
          AuthRemoteDataSource(apiDio: apiDio).signInWithGoogle('provider-token'),
          throwsA(isA<SocialTokenRejectedFailure>()),
        );

        expect(adapter.requestsTo(ApiEndpoints.authRefresh), isEmpty);
        expect(
          adapter.requestsTo(ApiEndpoints.authGoogle),
          hasLength(1),
          reason: 'повторов нет',
        );
        expect(
          adapter.requestsTo(ApiEndpoints.authGoogle).single.headers['Authorization'],
          isNull,
          reason: 'Bearer на публичный эндпоинт не подставляется',
        );
        expect(await tokens.readRefreshToken(), 'old-refresh');
        expect(sessionExpiredEvents, 0);
      },
    );

    test('401 от /auth/apple: то же самое', () async {
      setUpClients(
        refreshResponder: (_) async => jsonBody(tokenJson()),
        routes: {
          ApiEndpoints.authApple: (_) async =>
              jsonBody({'message': 'invalid id_token'}, status: 401),
        },
      );
      await signedInWith();

      await expectLater(
        AuthRemoteDataSource(apiDio: apiDio).signInWithApple('provider-token'),
        throwsA(isA<SocialTokenRejectedFailure>()),
      );

      expect(adapter.requestsTo(ApiEndpoints.authRefresh), isEmpty);
      expect(sessionExpiredEvents, 0);
    });

    test('вход без сохранённой сессии не завершает «сессию»', () async {
      setUpClients(
        refreshResponder: (_) async => jsonBody(tokenJson()),
        routes: {
          ApiEndpoints.authGoogle: (_) async => jsonBody(tokenJson()),
        },
      );

      final result = await AuthRemoteDataSource(
        apiDio: apiDio,
      ).signInWithGoogle('provider-token');

      expect(result.refreshToken, 'new-refresh');
      expect(adapter.requestsTo(ApiEndpoints.authRefresh), isEmpty);
    });

    test('logout при почти истёкшем access_token не вызывает refresh', () async {
      setUpClients(
        refreshResponder: (_) async => jsonBody(tokenJson()),
        now: () => now,
        routes: {
          ApiEndpoints.authLogout: (_) async => ResponseBody.fromString('', 204),
        },
      );
      // Истекает через 30 секунд: обычный запрос обновил бы токен заранее.
      await signedInWith(expiresAt: now.add(const Duration(seconds: 30)));

      await AuthRemoteDataSource(apiDio: apiDio).logout('old-refresh');

      expect(
        adapter.requestsTo(ApiEndpoints.authRefresh),
        isEmpty,
        reason: 'refresh сделал бы старый refresh-токен в теле недействительным',
      );
      final sent = adapter.requestsTo(ApiEndpoints.authLogout).single;
      expect(sent.data, {'refresh_token': 'old-refresh'});
      expect(sent.contentType, Headers.jsonContentType);
      expect(sent.headers['Authorization'], isNull);
    });

    test('обычный запрос в той же ситуации refresh вызывает', () async {
      // Контроль: без skipAuth упреждающий refresh в этом сценарии срабатывает.
      setUpClients(
        refreshResponder: (_) async => jsonBody(tokenJson()),
        now: () => now,
      );
      await signedInWith(expiresAt: now.add(const Duration(seconds: 30)));

      await apiDio.get<Object?>('/a');

      expect(adapter.requestsTo(ApiEndpoints.authRefresh), hasLength(1));
    });
  });

  test('без токенов запрос уходит без Authorization', () async {
    setUpClients(refreshResponder: (_) async => jsonBody(tokenJson()));

    await expectLater(
      apiDio.get<Object?>('/a'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requestsTo('/a').first.headers['Authorization'], isNull);
    // Сессии не было — и о конце сессии сообщать нечего.
    expect(sessionExpiredEvents, 0);
  });
}
