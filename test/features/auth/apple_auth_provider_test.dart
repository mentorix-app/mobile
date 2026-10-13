import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/auth/data/social/apple_auth_provider.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _state = 'state-from-app';
const _serviceId = 'com.mentorix.mobile.signin';
const _redirect = 'https://api.test/auth/apple/callback';

AuthorizationCredentialAppleID _credential({
  String? state = _state,
  String? identityToken = 'apple-id-token',
  String? givenName,
  String? familyName,
}) => AuthorizationCredentialAppleID(
  userIdentifier: 'apple-user',
  givenName: givenName,
  familyName: familyName,
  authorizationCode: 'code',
  email: null,
  identityToken: identityToken,
  state: state,
);

class _Call {
  _Call(this.scopes, this.web, this.state);

  final List<AppleIDAuthorizationScopes> scopes;
  final WebAuthenticationOptions? web;
  final String? state;
}

void main() {
  late List<_Call> calls;
  late List<String> warnings;

  AppleAuthProvider create({
    required AuthorizationCredentialAppleID Function(String? sentState) answer,
    TargetPlatform platform = TargetPlatform.iOS,
    String serviceId = _serviceId,
    String redirectUri = _redirect,
  }) {
    return AppleAuthProvider(
      request:
          ({required scopes, webAuthenticationOptions, state}) async {
            calls.add(_Call(scopes, webAuthenticationOptions, state));
            return answer(state);
          },
      stateGenerator: () => _state,
      platform: platform,
      serviceId: serviceId,
      redirectUri: redirectUri,
      onWarning: warnings.add,
    );
  }

  setUp(() {
    calls = [];
    warnings = [];
  });

  group('state', () {
    test('в запрос уходит сгенерированный state', () async {
      final provider = create(answer: (state) => _credential(state: state));

      await provider.signIn();

      expect(calls.single.state, _state);
    });

    test('совпал → токен принимается', () async {
      final provider = create(answer: (_) => _credential());

      final result = await provider.signIn();

      expect(result.idToken, 'apple-id-token');
    });

    test('не совпал → токен не отправляется, ошибка входа', () async {
      final provider = create(answer: (_) => _credential(state: 'другой'));

      await expectLater(
        provider.signIn(),
        throwsA(isA<SocialSignInStateMismatchFailure>()),
      );
    });

    test('Apple не вернула state вовсе → тоже несовпадение', () async {
      final provider = create(answer: (_) => _credential(state: null));

      await expectLater(
        provider.signIn(),
        throwsA(isA<SocialSignInStateMismatchFailure>()),
      );
    });

    test('state проверяется раньше токена: пустой токен не маскирует подмену', () {
      final provider = create(
        answer: (_) => _credential(state: 'другой', identityToken: null),
      );

      expect(
        provider.signIn(),
        throwsA(isA<SocialSignInStateMismatchFailure>()),
      );
    });

    test('каждый вход — новый state, достаточно длинный', () {
      final first = AppleAuthProvider.generateState();
      final second = AppleAuthProvider.generateState();

      expect(first, isNot(second));
      expect(first.length, greaterThanOrEqualTo(43), reason: '32 байта base64');
      expect(first, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });
  });

  group('платформы', () {
    test('iOS: нативный диалог, без webAuthenticationOptions', () async {
      final provider = create(answer: (_) => _credential());

      await provider.signIn();

      expect(provider.isAvailable, isTrue);
      expect(calls.single.web, isNull);
    });

    test('Android: кнопка доступна, веб-поток со Services ID и redirect', () async {
      final provider = create(
        platform: TargetPlatform.android,
        answer: (_) => _credential(),
      );

      await provider.signIn();

      expect(provider.isAvailable, isTrue);
      final web = calls.single.web!;
      expect(web.clientId, _serviceId);
      expect(web.redirectUri, Uri.parse(_redirect));
      expect(calls.single.state, _state, reason: 'state и в веб-потоке');
    });

    test('Android без Services ID или redirect: «не настроено»', () async {
      for (final provider in [
        create(
          platform: TargetPlatform.android,
          serviceId: 'YOUR_APPLE_SERVICE_ID',
          answer: (_) => _credential(),
        ),
        create(
          platform: TargetPlatform.android,
          redirectUri: '',
          answer: (_) => _credential(),
        ),
      ]) {
        await expectLater(
          provider.signIn(),
          throwsA(
            isA<SocialSignInNotConfiguredFailure>().having(
              (f) => f.provider,
              'provider',
              SocialProvider.apple,
            ),
          ),
        );
      }

      expect(calls, isEmpty, reason: 'до Apple дело не дошло');
      expect(warnings, isNotEmpty);
    });

    test('iOS не требует Services ID', () async {
      final provider = create(
        serviceId: '',
        redirectUri: '',
        answer: (_) => _credential(),
      );

      expect((await provider.signIn()).idToken, 'apple-id-token');
    });

    test('Linux/Windows: недоступно', () async {
      final provider = create(
        platform: TargetPlatform.linux,
        answer: (_) => _credential(),
      );

      expect(provider.isAvailable, isFalse);
      await expectLater(
        provider.signIn(),
        throwsA(isA<SocialSignInUnavailableFailure>()),
      );
    });
  });

  test('имя из первого входа собирается из имени и фамилии', () async {
    final provider = create(
      answer: (_) => _credential(givenName: ' Ivan ', familyName: 'Petrov'),
    );

    expect((await provider.signIn()).name, 'Ivan Petrov');
  });

  test('отмена в диалоге — не ошибка', () async {
    final provider = AppleAuthProvider(
      request: ({required scopes, webAuthenticationOptions, state}) async =>
          throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'canceled',
          ),
      stateGenerator: () => _state,
      platform: TargetPlatform.iOS,
    );

    await expectLater(
      provider.signIn(),
      throwsA(isA<SocialSignInCancelledFailure>()),
    );
  });
}
