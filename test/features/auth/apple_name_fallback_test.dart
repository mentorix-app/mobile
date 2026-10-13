import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mentorix_app/features/auth/data/social/apple_auth_provider.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../helpers/fake_http_adapter.dart';

class _FakeGoogle implements SocialAuthProvider {
  @override
  bool get isAvailable => true;

  @override
  Future<SocialCredential> signIn() async =>
      const SocialCredential(idToken: 'google-id-token');

  @override
  Future<void> disconnect() async {}
}

/// Имя из Apple как запасной путь: профиль пустой → `PATCH /auth/me`.
/// Весь стек: настоящие датасорс и репозиторий, HTTP — сценарный адаптер.
void main() {
  late FakeHttpAdapter adapter;
  late SessionCubit session;
  late AuthRepositoryImpl repository;
  late List<String> printed;
  late DebugPrintCallback originalDebugPrint;

  /// Имя в профиле на «сервере»; PATCH меняет его, как настоящий бэкенд.
  var serverName = '';

  /// Статус, которым сервер отвечает на PATCH; `null` — успех (204).
  int? patchStatus;

  /// Имена, которые Apple вернёт на очередных входах по порядку.
  late List<({String? given, String? family})> appleNames;

  Future<void> setUpStack({
    String initialServerName = '',
    int? failPatchWith,
    List<({String? given, String? family})>? names,
    String? pendingName,
  }) async {
    serverName = initialServerName;
    patchStatus = failPatchWith;
    appleNames = [...?names];

    FlutterSecureStorage.setMockInitialValues({
      StorageKeys.pendingAppleName: ?pendingName,
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    adapter = FakeHttpAdapter((options) async {
      final key = '${options.method} ${options.path}';
      return switch (key) {
        'POST ${ApiEndpoints.authApple}' ||
        'POST ${ApiEndpoints.authGoogle}' => jsonBody(tokenJson()),
        'GET ${ApiEndpoints.authMe}' => jsonBody({
          'user_id': 'user-1',
          'email': 'user@example.com',
          'name': serverName,
          'telegram_linked': true,
        }),
        'PATCH ${ApiEndpoints.authMe}' =>
          patchStatus != null
              ? jsonBody({'code': 'internal', 'message': 'x'},
                  status: patchStatus!)
              : () {
                  serverName =
                      (options.data as Map<String, dynamic>)['name'] as String;
                  return ResponseBody.fromString('', 204);
                }(),
        'GET ${ApiEndpoints.clientTrainers}' => jsonBody({'items': <Object>[]}),
        _ => throw StateError('unexpected request $key'),
      };
    });

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.test',
        contentType: Headers.jsonContentType,
      ),
    )..httpClientAdapter = adapter;

    repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(apiDio: dio),
      tokens: TokenStorage(const FlutterSecureStorage(), prefs),
      sessionExpired: SessionExpiredNotifier(),
      pendingAppleName: PendingAppleNameStorage(const FlutterSecureStorage()),
      google: _FakeGoogle(),
      apple: AppleAuthProvider(
        request: ({required scopes, webAuthenticationOptions, state}) async {
          final names = appleNames.isEmpty
              ? (given: null, family: null)
              : appleNames.removeAt(0);
          return AuthorizationCredentialAppleID(
            userIdentifier: 'apple-user',
            givenName: names.given,
            familyName: names.family,
            authorizationCode: 'code',
            email: null,
            identityToken: 'apple-id-token',
            state: state,
          );
        },
        platform: TargetPlatform.iOS,
      ),
    );
    session = SessionCubit(repository, SessionExpiredNotifier());
  }

  /// Вход как в `LoginCubit`: токены, затем `/auth/me` и `/client/trainers`.
  Future<void> signInWithApple() async {
    await repository.signInWithApple();
    await session.authenticate();
  }

  Iterable<RequestOptions> patches() =>
      adapter.requests.where((r) => r.method == 'PATCH');

  Future<String?> pending() =>
      PendingAppleNameStorage(const FlutterSecureStorage()).read();

  bool logged(String text) => printed.any((l) => l.contains('name fallback: $text'));

  String profileName() =>
      (session.state as SessionAuthenticated).profile.name;

  setUp(() {
    printed = [];
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });

  tearDown(() async {
    debugPrint = originalDebugPrint;
    DebugLog.debugModeOverride = null;
    await session.close();
  });

  test('имя пустое, Apple дала имя → PATCH ушёл, профиль обновлён', () async {
    await setUpStack(names: [(given: 'Ivan', family: 'Petrov')]);

    await signInWithApple();

    final order = adapter.requests.map((r) => '${r.method} ${r.path}').toList();
    expect(order, [
      'POST /auth/apple',
      'GET /auth/me',
      'PATCH /auth/me',
      'GET /auth/me',
      'GET /client/trainers',
    ]);
    expect(patches().single.data, {'name': 'Ivan Petrov'});
    expect(session.state, isA<SessionAuthenticated>());
    expect(profileName(), 'Ivan Petrov');
    expect(await pending(), isNull, reason: 'имя записано — хранить нечего');
    expect(logged('PATCH sent'), isTrue);
  });

  test('только givenName тоже годится', () async {
    await setUpStack(names: [(given: 'Ivan', family: null)]);

    await signInWithApple();

    expect(patches().single.data, {'name': 'Ivan'});
  });

  test('имя на сервере есть → PATCH не ушёл, имя не перезаписано', () async {
    await setUpStack(
      initialServerName: 'Existing Name',
      names: [(given: 'Ivan', family: 'Petrov')],
    );

    await signInWithApple();

    expect(patches(), isEmpty);
    expect(profileName(), 'Existing Name');
    expect(await pending(), isNull);
    expect(logged('skipped (server has name)'), isTrue);
  });

  test('PATCH упал → вход успешен, имя ждёт следующей попытки', () async {
    await setUpStack(
      failPatchWith: 500,
      names: [(given: 'Ivan', family: 'Petrov')],
    );

    await signInWithApple();

    expect(session.state, isA<SessionAuthenticated>());
    expect(profileName(), isEmpty);
    expect(patches(), hasLength(1));
    expect(await pending(), 'Ivan Petrov');
    expect(logged('failed'), isTrue);
    expect(logged('PATCH sent'), isFalse);
  });

  test('после сбоя следующий вход берёт имя из хранилища и дописывает', () async {
    await setUpStack(
      failPatchWith: 500,
      names: [
        (given: 'Ivan', family: 'Petrov'),
        // Второй раз Apple имя уже не отдаёт.
        (given: null, family: null),
      ],
    );
    await signInWithApple();
    expect(await pending(), 'Ivan Petrov');

    patchStatus = null;
    adapter.requests.clear();
    await signInWithApple();

    expect(
      (adapter.requests.firstWhere((r) => r.path == ApiEndpoints.authApple).data
          as Map)['name'],
      'Ivan Petrov',
      reason: 'имя взято из PendingAppleNameStorage',
    );
    expect(patches().single.data, {'name': 'Ivan Petrov'});
    expect(profileName(), 'Ivan Petrov');
    expect(await pending(), isNull);
  });

  test('PATCH один раз за вход: повторный /auth/me его не шлёт', () async {
    await setUpStack(
      failPatchWith: 500,
      names: [(given: 'Ivan', family: 'Petrov')],
    );
    await signInWithApple();

    await repository.getProfile(forceRefresh: true);
    await repository.getProfile(forceRefresh: true);

    expect(patches(), hasLength(1));
  });

  test('имени нет нигде → PATCH не нужен, в журнале понятно почему', () async {
    await setUpStack();

    await signInWithApple();

    expect(patches(), isEmpty);
    expect(session.state, isA<SessionAuthenticated>());
    expect(logged('skipped (no name from Apple)'), isTrue);
  });

  test('вход через Google с пустым именем PATCH не шлёт', () async {
    await setUpStack();

    await repository.signInWithGoogle();
    await session.authenticate();

    expect(patches(), isEmpty);
    expect(printed.where((l) => l.contains('name fallback')), isEmpty);
  });

  test('имя длиннее 100 символов обрезается: иначе PATCH ответит 400', () async {
    await setUpStack(names: [(given: 'А' * 150, family: null)]);

    await signInWithApple();

    final sent = (patches().single.data as Map)['name'] as String;
    expect(sent.runes.length, 100);
  });

  test('release: PATCH работает, журнала нет', () async {
    DebugLog.debugModeOverride = false;
    await setUpStack(names: [(given: 'Ivan', family: 'Petrov')]);

    await signInWithApple();

    expect(patches(), hasLength(1));
    expect(profileName(), 'Ivan Petrov');
    expect(printed, isEmpty);
  });
}
