import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/network/dio_factory.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mentorix_app/features/auth/data/social/apple_auth_provider.dart';
import 'package:mentorix_app/features/auth/data/social/sign_in_nonce.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_en.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_ru.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/talker_capture.dart';

class _FakeGoogle implements SocialAuthProvider {
  bool? lastWithNonce;

  @override
  bool get isAvailable => true;

  @override
  Future<SocialCredential> signIn({bool withNonce = false}) async {
    lastWithNonce = withNonce;
    return const SocialCredential(idToken: 'google-id-token');
  }

  @override
  Future<void> disconnect() async {}
}

/// Что Apple получила в запросе и что вернула: `nonce` — это хеш.
class _AppleCall {
  _AppleCall(this.nonce);

  final String? nonce;
}

void main() {
  // Известные векторы SHA-256 (FIPS 180-2).
  const abcHash =
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
  const emptyHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  const twoBlockInput = 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
  const twoBlockHash =
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1';

  group('SignInNonce', () {
    test('hash: известные векторы SHA-256, hex в нижнем регистре', () {
      expect(SignInNonce.hash('abc'), abcHash);
      expect(SignInNonce.hash(''), emptyHash);
      expect(SignInNonce.hash(twoBlockInput), twoBlockHash);
      expect(SignInNonce.hash('abc'), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('hashed считается от raw', () {
      expect(const SignInNonce('abc').hashed, abcHash);
    });

    test('generate: 32 байта в base64url без заполнения', () {
      final raw = SignInNonce.generate().raw;

      // 32 байта = 43 символа base64 без «=».
      expect(raw, hasLength(43));
      expect(raw, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('generate: каждый раз новое значение', () {
      final values = {for (var i = 0; i < 200; i++) SignInNonce.generate().raw};

      expect(values, hasLength(200));
    });
  });

  group('AppleAuthProvider и nonce', () {
    late List<_AppleCall> calls;

    AppleAuthProvider create({
      TargetPlatform platform = TargetPlatform.iOS,
      String Function()? nonceGenerator,
    }) {
      return AppleAuthProvider(
        request:
            ({
              required scopes,
              webAuthenticationOptions,
              nonce,
              state,
            }) async {
              calls.add(_AppleCall(nonce));
              return AuthorizationCredentialAppleID(
                userIdentifier: 'apple-user',
                givenName: null,
                familyName: null,
                authorizationCode: 'apple-auth-code',
                email: null,
                identityToken: 'apple-id-token',
                state: state,
              );
            },
        nonceGenerator: nonceGenerator,
        platform: platform,
        serviceId: 'com.mentorix.mobile.signin',
        redirectUri: 'https://api.test/auth/apple/callback',
        onWarning: (_) {},
      );
    }

    setUp(() => calls = []);

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      test('${platform.name}: Apple получает хеш, бэкенду уходит исходная '
          'строка', () async {
        final provider = create(
          platform: platform,
          nonceGenerator: () => 'abc',
        );

        final credential = await provider.signIn(withNonce: true);

        expect(calls.single.nonce, abcHash);
        expect(credential.nonce, 'abc');
      });
    }

    test('nonce новый на каждую попытку, повторно не используется', () async {
      final provider = create();

      final first = await provider.signIn(withNonce: true);
      final second = await provider.signIn(withNonce: true);

      expect(first.nonce, isNot(second.nonce));
      expect(calls[0].nonce, isNot(calls[1].nonce));
      expect(calls[0].nonce, SignInNonce.hash(first.nonce!));
      expect(calls[1].nonce, SignInNonce.hash(second.nonce!));
    });

    test('хеш провайдеру — не исходная строка', () async {
      final provider = create();

      final credential = await provider.signIn(withNonce: true);

      expect(calls.single.nonce, isNot(credential.nonce));
    });

    test('удаление аккаунта (без withNonce): nonce нет нигде', () async {
      final provider = create();

      final credential = await provider.signIn();

      expect(calls.single.nonce, isNull);
      expect(credential.nonce, isNull);
    });
  });

  group('вход через весь стек', () {
    late FakeHttpAdapter adapter;
    late AuthRepositoryImpl repository;
    late SessionExpiredNotifier notifier;
    late TokenStorage tokens;
    late _FakeGoogle google;
    late List<String?> appleHashes;

    /// Ответ сервера на `POST /auth/apple`; по умолчанию успех.
    late FakeResponder appleResponder;

    Future<void> setUpStack() async {
      resetTalker();
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      appleHashes = [];
      google = _FakeGoogle();
      notifier = SessionExpiredNotifier();
      tokens = TokenStorage(const FlutterSecureStorage(), prefs);
      appleResponder = (_) async => jsonBody(tokenJson());

      adapter = FakeHttpAdapter((options) async {
        return switch (options.path) {
          ApiEndpoints.authApple => appleResponder(options),
          ApiEndpoints.authGoogle => jsonBody(tokenJson()),
          _ => throw StateError('unexpected request ${options.path}'),
        };
      });

      final plainDio = createPlainDio()..httpClientAdapter = adapter;
      final apiDio = createApiDio(
        plainDio: plainDio,
        tokens: tokens,
        sessionExpired: notifier,
      )..httpClientAdapter = adapter;

      repository = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(apiDio: apiDio),
        tokens: tokens,
        sessionExpired: notifier,
        pendingAppleName: PendingAppleNameStorage(const FlutterSecureStorage()),
        google: google,
        apple: AppleAuthProvider(
          request:
              ({
                required scopes,
                webAuthenticationOptions,
                nonce,
                state,
              }) async {
                appleHashes.add(nonce);
                return AuthorizationCredentialAppleID(
                  userIdentifier: 'apple-user',
                  givenName: null,
                  familyName: null,
                  authorizationCode: 'apple-auth-code',
                  email: null,
                  identityToken: 'apple-id-token',
                  state: state,
                );
              },
          platform: TargetPlatform.iOS,
        ),
      );
    }

    Iterable<Map<String, dynamic>> appleBodies() => adapter
        .requestsTo(ApiEndpoints.authApple)
        .map((r) => r.data as Map<String, dynamic>);

    setUp(setUpStack);

    test('исходная строка уходит на бэкенд, её хеш — Apple', () async {
      await repository.signInWithApple();

      final body = appleBodies().single;
      final raw = body['nonce'] as String;

      expect(appleHashes.single, SignInNonce.hash(raw));
      expect(raw, isNot(appleHashes.single));
      expect(body['id_token'], 'apple-id-token');
    });

    test('каждая попытка входа — новый nonce и в Apple, и на бэкенд', () async {
      await repository.signInWithApple();
      await repository.signInWithApple();

      final raws = [for (final b in appleBodies()) b['nonce'] as String];

      expect(raws[0], isNot(raws[1]));
      expect(appleHashes[0], isNot(appleHashes[1]));
    });

    test('повтор после ошибки не берёт старый nonce', () async {
      var attempt = 0;
      appleResponder = (_) async => attempt++ == 0
          ? jsonBody({'code': 'invalid_id_token', 'message': 'x'}, status: 401)
          : jsonBody(tokenJson());

      await expectLater(
        repository.signInWithApple(),
        throwsA(isA<SocialTokenRejectedFailure>()),
      );
      await repository.signInWithApple();

      final raws = [for (final b in appleBodies()) b['nonce'] as String];
      expect(raws, hasLength(2));
      expect(raws[0], isNot(raws[1]));
    });

    test('Google пока без nonce: поле не отправляется, вход как раньше', () async {
      await repository.signInWithGoogle();

      final body =
          adapter.requestsTo(ApiEndpoints.authGoogle).single.data
              as Map<String, dynamic>;

      expect(body, {'id_token': 'google-id-token'});
      expect(google.lastWithNonce, isFalse);
    });

    test('401 invalid_id_token на входе: вход не удался, сессия не кончается, '
        'refresh не запускается', () async {
      appleResponder = (_) async =>
          jsonBody({'code': 'invalid_id_token', 'message': 'x'}, status: 401);
      var sessionExpiredEvents = 0;
      final sub = notifier.stream.listen((_) => sessionExpiredEvents++);

      await expectLater(
        repository.signInWithApple(),
        throwsA(isA<SocialTokenRejectedFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(adapter.requestsTo(ApiEndpoints.authRefresh), isEmpty);
      expect(sessionExpiredEvents, 0);
      expect(adapter.requestsTo(ApiEndpoints.authApple), hasLength(1));
    });

    test('в логах nonce скрыт: *** вместо исходной строки', () async {
      await repository.signInWithApple();

      final raw = appleBodies().single['nonce'] as String;
      final output = loggedText().join('\n');

      expect(output, contains('/auth/apple'));
      expect(output, isNot(contains(raw)));
      expect(output, contains('***'));
    });
  });

  test('отказ токена на входе: «вход не удался, попробуйте ещё раз»', () {
    const failure = SocialTokenRejectedFailure();

    expect(
      failure.message(AppLocalizationsRu(), debug: false),
      'Вход не удался. Попробуйте ещё раз.',
    );
    expect(
      failure.message(AppLocalizationsEn(), debug: false),
      'Sign-in failed. Try again.',
    );
    // Не «сессия закончилась»: сессия при неудачном входе не затрагивается.
    expect(failure, isNot(isA<SessionExpiredFailure>()));
  });
}
