import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
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

const _identityToken = 'SECRET-apple-identity-token';
const _authCode = 'SECRET-apple-authorization-code';

class _NoGoogle implements SocialAuthProvider {
  @override
  bool get isAvailable => true;

  @override
  Future<SocialCredential> signIn({bool withNonce = false}) async =>
      throw const SocialSignInUnavailableFailure();

  @override
  Future<void> disconnect() async {}
}

/// Вход через Apple не пишет в debug-журнал подробностей: ни credential, ни
/// источник имени, ни тело запроса (тело пишет только `MaskedTalkerDioLogger`).
/// Имя при этом по-прежнему уходит в `POST /auth/apple`.
void main() {
  late FakeHttpAdapter adapter;

  /// [pendingName] — имя, сохранённое после прошлой неудачной попытки.
  Future<void> signIn({
    String? givenName,
    String? familyName,
    String? pendingName,
  }) async {
    FlutterSecureStorage.setMockInitialValues({
      StorageKeys.pendingAppleName: ?pendingName,
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    adapter = FakeHttpAdapter((options) async => jsonBody(tokenJson()));
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;

    final repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(apiDio: dio),
      tokens: TokenStorage(const FlutterSecureStorage(), prefs),
      sessionExpired: SessionExpiredNotifier(),
      pendingAppleName: PendingAppleNameStorage(const FlutterSecureStorage()),
      google: _NoGoogle(),
      apple: AppleAuthProvider(
        request: ({required scopes, webAuthenticationOptions, nonce, state}) async =>
            AuthorizationCredentialAppleID(
              userIdentifier: 'apple-user',
              givenName: givenName,
              familyName: familyName,
              authorizationCode: _authCode,
              email: null,
              identityToken: _identityToken,
              state: state,
            ),
        platform: TargetPlatform.iOS,
      ),
    );

    await repository.signInWithApple();
  }

  List<String> appleLines() =>
      loggedMessages().where((l) => l.startsWith('[mentorix.apple]')).toList();

  setUp(resetTalker);

  tearDown(() => DebugLog.debugModeOverride = null);

  test('Apple отдал имя: оно уходит в тело, а подробностей в журнале нет',
      () async {
    await signIn(givenName: 'Ivan', familyName: 'Petrov');

    expect(adapter.requests.single.data, {
      'id_token': _identityToken,
      'name': 'Ivan Petrov',
      'nonce': isA<String>(),
    });
    expect(appleLines(), isEmpty, reason: 'ни credential, ни источника имени');
    expect(loggedMessages().join('\n'), isNot(contains('Ivan')));
  });

  test('имя из PendingAppleNameStorage уходит в тело, журнал пуст', () async {
    await signIn(pendingName: 'Saved Name');

    expect((adapter.requests.single.data as Map)['name'], 'Saved Name');
    expect(appleLines(), isEmpty);
  });

  test('имени нет нигде: поля name в теле нет, журнал пуст', () async {
    await signIn();

    expect((adapter.requests.single.data as Map).containsKey('name'), isFalse);
    expect(appleLines(), isEmpty);
  });

  test('токены и код авторизации в журнал не попадают', () async {
    await signIn(givenName: 'Ivan', familyName: 'Petrov');

    final all = loggedMessages().join('\n');
    expect(all, isNot(contains(_identityToken)));
    expect(all, isNot(contains(_authCode)));
    expect(all, isNot(contains('new-access')));
    expect(all, isNot(contains('new-refresh')));
    expect(all, isNot(contains('Bearer')));
  });

  test('release: вход работает, а журнала нет вовсе', () async {
    DebugLog.debugModeOverride = false;

    await signIn(givenName: 'Ivan', familyName: 'Petrov');

    expect(loggedMessages(), isEmpty);
    expect((adapter.requests.single.data as Map)['name'], 'Ivan Petrov');
  });
}
