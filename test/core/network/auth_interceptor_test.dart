import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
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
  }) {
    adapter = FakeHttpAdapter((options) async {
      if (options.path == '/auth/refresh') return refreshResponder(options);

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
          adapter.requestsTo('/auth/refresh'),
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

      final refresh = adapter.requestsTo('/auth/refresh').single;
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
      expect(adapter.requestsTo('/auth/refresh'), hasLength(1));

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

      expect(adapter.requestsTo('/auth/refresh'), hasLength(1));
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

      expect(adapter.requestsTo('/auth/refresh'), hasLength(1));
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
      expect(adapter.requestsTo('/auth/refresh'), hasLength(1));

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
      expect(adapter.requestsTo('/auth/refresh'), isEmpty);
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
