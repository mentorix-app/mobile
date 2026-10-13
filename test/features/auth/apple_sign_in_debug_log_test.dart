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
  Future<SocialCredential> signIn() async =>
      throw const SocialSignInUnavailableFailure();

  @override
  Future<void> disconnect() async {}
}

/// Debug-журнал входа через Apple: что вернул Apple, ушло ли имя в тело
/// `POST /auth/apple` и откуда оно взято. Токены в журнал не попадают.
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
        request: ({required scopes, webAuthenticationOptions, state}) async =>
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

  test('Apple отдал имя: оно в журнале и в теле, источник — credential', () async {
    await signIn(givenName: 'Ivan', familyName: 'Petrov');

    final lines = appleLines();
    expect(
      lines.any(
        (l) => l.contains('givenName="Ivan"') && l.contains('familyName="Petrov"'),
      ),
      isTrue,
      reason: 'значения givenName и familyName видны',
    );
    expect(
      lines.any((l) => l.contains('name source: Apple credential')),
      isTrue,
    );
    expect(
      lines.any((l) => l.contains('POST /auth/apple') && l.contains('name="Ivan Petrov"')),
      isTrue,
      reason: 'поле name в теле и его значение',
    );

    // Журнал совпадает с реальным телом запроса.
    expect(adapter.requests.single.data, {
      'id_token': _identityToken,
      'name': 'Ivan Petrov',
    });
  });

  test('Apple имени не отдал, но оно сохранено: источник — PendingAppleNameStorage',
      () async {
    await signIn(pendingName: 'Saved Name');

    final lines = appleLines();
    expect(
      lines.any((l) => l.contains('givenName=null') && l.contains('familyName=null')),
      isTrue,
    );
    expect(
      lines.any((l) => l.contains('name source: PendingAppleNameStorage')),
      isTrue,
    );
    expect(lines.any((l) => l.contains('name="Saved Name"')), isTrue);
    expect((adapter.requests.single.data as Map)['name'], 'Saved Name');
  });

  test('имени нет нигде: поля name в теле нет, и это видно в журнале', () async {
    await signIn();

    final lines = appleLines();
    expect(lines.any((l) => l.contains('name source: none')), isTrue);
    expect(lines.any((l) => l.contains('body:') && l.contains('name=absent')), isTrue);
    expect((adapter.requests.single.data as Map).containsKey('name'), isFalse);
  });

  test('токены и код авторизации в журнал не попадают', () async {
    await signIn(givenName: 'Ivan', familyName: 'Petrov');

    final all = loggedMessages().join('\n');
    expect(all, isNot(contains(_identityToken)));
    expect(all, isNot(contains(_authCode)));
    expect(all, isNot(contains('new-access')));
    expect(all, isNot(contains('new-refresh')));
    expect(all, isNot(contains('Bearer')));
    // Но наличие токена отмечено.
    expect(all, contains('identityToken=yes'));
    expect(all, contains('id_token=yes'));
  });

  test('release: вход работает, а журнала нет вовсе', () async {
    DebugLog.debugModeOverride = false;

    await signIn(givenName: 'Ivan', familyName: 'Petrov');

    expect(loggedMessages(), isEmpty);
    expect((adapter.requests.single.data as Map)['name'], 'Ivan Petrov');
  });
}
