import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mentorix_app/features/auth/data/social/apple_auth_provider.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/talker_capture.dart';

const _redirect = 'https://api.test/auth/apple/callback';

class _FakeGoogle implements SocialAuthProvider {
  int disconnects = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<SocialCredential> signIn() async =>
      throw const SocialSignInUnavailableFailure();

  @override
  Future<void> disconnect() async => disconnects++;
}

Map<String, Object?> _error(String code) => {
  'code': code,
  // Текст бэкенд вправе менять: клиент его не разбирает.
  'message': 'любой текст',
};

/// Удаление аккаунта через весь стек: Dio + [AuthInterceptor] + датасорс +
/// репозиторий + настоящий [AppleAuthProvider] (подменено только окно Apple),
/// HTTP — сценарный адаптер.
void main() {
  late FakeHttpAdapter adapter;
  late TokenStorage tokens;
  late _FakeGoogle google;
  late SessionExpiredNotifier notifier;
  late int appleWindows;
  late AuthRepositoryImpl repository;
  late int sessionExpiredEvents;

  /// [responses] — ответы на `DELETE /auth/me` по порядку; refresh фиксируется
  /// и отвечает успехом, чтобы лишний refresh был виден.
  Future<void> setUp0(
    List<ResponseBody Function()> responses, {
    TargetPlatform platform = TargetPlatform.iOS,
    bool appleCancels = false,
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      StorageKeys.secureStorageInstallFlag: true,
    });
    final prefs = await SharedPreferences.getInstance();
    tokens = TokenStorage(const FlutterSecureStorage(), prefs);
    await tokens.save(
      const AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        userId: 'user-1',
      ),
    );

    var next = 0;
    adapter = FakeHttpAdapter((options) async {
      if (options.path == ApiEndpoints.authRefresh) {
        return jsonBody({
          'access_token': 'refreshed-access',
          'token_type': 'Bearer',
          'expires_at': '2100-01-01T00:00:00Z',
          'user_id': 'user-1',
          'refresh_token': 'refreshed-refresh',
        });
      }
      expect(options.method, 'DELETE');
      expect(options.path, ApiEndpoints.authMe);
      return responses[next++]();
    });

    notifier = SessionExpiredNotifier();
    sessionExpiredEvents = 0;
    notifier.stream.listen((_) => sessionExpiredEvents++);

    BaseOptions baseOptions() => BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    );
    final plainDio = Dio(baseOptions())..httpClientAdapter = adapter;
    final apiDio = Dio(baseOptions())
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          tokens: tokens,
          plainDio: plainDio,
          sessionExpired: notifier,
        ),
      );

    appleWindows = 0;
    google = _FakeGoogle();
    final apple = AppleAuthProvider(
      request: ({required scopes, webAuthenticationOptions, state}) async {
        appleWindows++;
        if (appleCancels) {
          throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'canceled',
          );
        }
        return AuthorizationCredentialAppleID(
          userIdentifier: 'apple-user',
          givenName: null,
          familyName: null,
          // Код новый на каждое окно: он одноразовый.
          authorizationCode: 'auth-code-$appleWindows',
          email: null,
          identityToken: 'apple-id-token-$appleWindows',
          state: state,
        );
      },
      platform: platform,
      serviceId: 'com.mentorix.mobile.signin',
      redirectUri: _redirect,
    );

    repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(apiDio: apiDio),
      tokens: tokens,
      sessionExpired: notifier,
      pendingAppleName: PendingAppleNameStorage(const FlutterSecureStorage()),
      google: google,
      apple: apple,
    );
  }

  ResponseBody Function() ok() =>
      () => ResponseBody.fromString('', 204);

  ResponseBody Function() fail(int status, String code) =>
      () => jsonBody(_error(code), status: status);

  Iterable<RequestOptions> deletes() => adapter.requestsTo(ApiEndpoints.authMe);

  Future<void> expectSessionKept() async {
    expect(await tokens.readAccessToken(), 'access');
    expect(await tokens.readRefreshToken(), 'refresh');
    expect(google.disconnects, 0, reason: 'аккаунт не удалён');
    expect(sessionExpiredEvents, 0);
  }

  group('debug-журнал потока', () {
    setUp(resetTalker);

    tearDown(() => DebugLog.debugModeOverride = null);

    List<String> flow() => loggedMessages()
        .where((l) => l.startsWith('[mentorix.delete]'))
        .map((l) => l.replaceFirst('[mentorix.delete] ', ''))
        .toList();

    test('шаги по порядку: без тела → 422 → окно Apple → повтор с телом',
        () async {
      await setUp0([fail(422, 'apple_authorization_required'), ok()]);

      await repository.deleteAccount();

      expect(flow(), [
        'step 1: request without body',
        'DELETE /auth/me body: none',
        'step 2: got 422 apple_authorization_required',
        'step 3: Apple window opened',
        'step 3: Apple window returned authorization_code=yes',
        'step 4: retry with body',
        'DELETE /auth/me body: apple_id_token=yes '
            'apple_authorization_code=yes apple_redirect_uri=no',
        'done: tokens cleared, Google disconnect requested',
      ]);
    });

    test('Android: apple_redirect_uri=yes, значение адреса не пишется', () async {
      await setUp0(
        [fail(422, 'apple_authorization_required'), ok()],
        platform: TargetPlatform.android,
      );

      await repository.deleteAccount();

      expect(
        flow(),
        contains(
          'DELETE /auth/me body: apple_id_token=yes '
          'apple_authorization_code=yes apple_redirect_uri=yes',
        ),
      );
    });

    test('значения токена и кода в журнал не попадают', () async {
      await setUp0([fail(422, 'apple_authorization_required'), ok()]);

      await repository.deleteAccount();

      final all = loggedMessages().join('\n');
      expect(all, isNot(contains('apple-id-token-1')));
      expect(all, isNot(contains('auth-code-1')));
      expect(all, isNot(contains('Bearer')));
    });

    test('повтор после отказа Apple: первый шаг пропущен', () async {
      await setUp0([ok()]);

      await repository.deleteAccount(confirmWithApple: true);

      expect(flow().first, 'step 1: bodyless request skipped, Apple already required');
    });

    test('закрытое окно Apple отмечено в журнале', () async {
      await setUp0([
        fail(422, 'apple_authorization_required'),
      ], appleCancels: true);

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<SocialSignInCancelledFailure>()),
      );

      expect(flow(), contains('step 3: Apple window cancelled by user'));
      expect(flow().any((l) => l.startsWith('done')), isFalse);
    });

    test('release: поток работает, журнала нет', () async {
      DebugLog.debugModeOverride = false;
      await setUp0([fail(422, 'apple_authorization_required'), ok()]);

      await repository.deleteAccount();

      expect(loggedMessages(), isEmpty);
      expect(deletes(), hasLength(2));
      expect(await tokens.readRefreshToken(), isNull);
    });
  });

  group('успех', () {
    test('204: запрос без тела с Bearer, токены очищены, Google отключён', () async {
      await setUp0([ok()]);

      await repository.deleteAccount();

      final request = deletes().single;
      expect(request.method, 'DELETE');
      expect(request.headers['Authorization'], 'Bearer access');
      expect(request.data, isNull, reason: 'аккаунт без входа через Apple');
      expect(appleWindows, 0);

      expect(await tokens.readAccessToken(), isNull);
      expect(await tokens.readRefreshToken(), isNull);
      expect(google.disconnects, 1);
    });

    test('404 user_not_found: уже удалён — это успех', () async {
      await setUp0([fail(404, 'user_not_found')]);

      await repository.deleteAccount();

      expect(await tokens.readRefreshToken(), isNull);
      expect(google.disconnects, 1);
    });
  });

  group('аккаунт со входом через Apple', () {
    test('422 → окно Apple → повтор с телом, apple_redirect_uri не шлётся на iOS',
        () async {
      await setUp0([fail(422, 'apple_authorization_required'), ok()]);

      await repository.deleteAccount();

      expect(appleWindows, 1);
      final requests = deletes().toList();
      expect(requests, hasLength(2));
      expect(requests.first.data, isNull);

      final retry = requests.last;
      expect(retry.contentType, Headers.jsonContentType);
      expect(retry.data, {
        'apple_id_token': 'apple-id-token-1',
        'apple_authorization_code': 'auth-code-1',
      });
      expect(
        (retry.data as Map).containsKey('apple_redirect_uri'),
        isFalse,
        reason: 'на iOS поле не отправляется',
      );
      expect(jsonEncode(retry.data), isNot(contains('redirect')));

      expect(await tokens.readRefreshToken(), isNull);
      expect(google.disconnects, 1);
    });

    test('на Android в теле есть apple_redirect_uri — тот же, что redirectUri',
        () async {
      await setUp0(
        [fail(422, 'apple_authorization_required'), ok()],
        platform: TargetPlatform.android,
      );

      await repository.deleteAccount();

      expect(deletes().last.data, {
        'apple_id_token': 'apple-id-token-1',
        'apple_authorization_code': 'auth-code-1',
        'apple_redirect_uri': _redirect,
      });
    });

    test('код берётся после 422, а не заранее', () async {
      await setUp0([ok()]);

      await repository.deleteAccount();

      expect(appleWindows, 0, reason: 'без 422 окно Apple не показывается');
    });

    test('confirmWithApple: окно сразу, первый же запрос с телом', () async {
      await setUp0([ok()]);

      await repository.deleteAccount(confirmWithApple: true);

      expect(appleWindows, 1);
      expect(deletes(), hasLength(1));
      expect((deletes().single.data as Map)['apple_authorization_code'],
          'auth-code-1');
    });

    test('404 user_not_found на запросе с телом — тоже успех', () async {
      await setUp0([
        fail(422, 'apple_authorization_required'),
        fail(404, 'user_not_found'),
      ]);

      await repository.deleteAccount();

      expect(await tokens.readRefreshToken(), isNull);
      expect(google.disconnects, 1);
    });

    test('пользователь закрыл окно Apple: аккаунт и токены целы', () async {
      await setUp0([
        fail(422, 'apple_authorization_required'),
      ], appleCancels: true);

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<SocialSignInCancelledFailure>()),
      );

      expect(deletes(), hasLength(1));
      await expectSessionKept();
    });

    test('повторный 422 после окна не зацикливается', () async {
      await setUp0([
        fail(422, 'apple_authorization_required'),
        fail(422, 'apple_authorization_required'),
      ]);

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<AppleAuthorizationRequiredFailure>()),
      );

      expect(deletes(), hasLength(2));
      expect(appleWindows, 1);
      await expectSessionKept();
    });
  });

  group('отказ Apple: предложить окно заново', () {
    test('401 invalid_id_token: ошибка, refresh и повтор не запускаются', () async {
      await setUp0([
        fail(422, 'apple_authorization_required'),
        fail(401, 'invalid_id_token'),
      ]);

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<AppleProofRejectedFailure>()),
      );

      // 401 — не «Bearer протух»: refresh не нужен, а повтор потратил бы код.
      expect(adapter.requestsTo(ApiEndpoints.authRefresh), isEmpty);
      expect(deletes(), hasLength(2));
      await expectSessionKept();
    });

    test('400 invalid_apple_authorization_code', () async {
      await setUp0([
        fail(422, 'apple_authorization_required'),
        fail(400, 'invalid_apple_authorization_code'),
      ]);

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<AppleProofRejectedFailure>()),
      );

      await expectSessionKept();
    });

    test('403 apple_account_mismatch: вошли другим Apple ID', () async {
      await setUp0([
        fail(422, 'apple_authorization_required'),
        fail(403, 'apple_account_mismatch'),
      ]);

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<AppleAccountMismatchFailure>()),
      );

      await expectSessionKept();
    });
  });

  group('остальные ответы: аккаунт не удалён, сессия цела', () {
    final cases = <String, (int, String, Type)>{
      '409 account_deletion_unavailable — в поддержку': (
        409,
        'account_deletion_unavailable',
        AccountDeletionUnavailableFailure,
      ),
      '502 apple_revocation_failed — позже': (
        502,
        'apple_revocation_failed',
        AccountDeletionFailedFailure,
      ),
      '503 provider_not_configured — позже': (
        503,
        'provider_not_configured',
        AccountDeletionFailedFailure,
      ),
      '503 без известного code — позже': (
        503,
        'service_unavailable',
        AccountDeletionFailedFailure,
      ),
      '429 rate_limited': (429, 'rate_limited', TooManyRequestsFailure),
    };

    cases.forEach((name, expected) {
      test(name, () async {
        await setUp0([fail(expected.$1, expected.$2)]);

        await expectLater(
          repository.deleteAccount(),
          throwsA(
            predicate<Object>((e) => e.runtimeType == expected.$3, '${expected.$3}'),
          ),
        );

        expect(appleWindows, 0);
        await expectSessionKept();
      });
    });

    test('нет связи: ошибка сети, сессия цела', () async {
      await setUp0([
        () => throw DioException.connectionError(
          requestOptions: RequestOptions(path: ApiEndpoints.authMe),
          reason: 'offline',
        ),
      ]);

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<NetworkFailure>()),
      );

      await expectSessionKept();
    });
  });
}
