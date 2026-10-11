import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mentorix_app/core/config/social_auth_config.dart';
import 'package:mentorix_app/features/auth/data/social/google_auth_provider.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

/// Подмена `GoogleSignIn`: запоминает параметры `initialize` и «закрывает»
/// окно входа. Настоящий аккаунт сконструировать нельзя (конструктор приватный).
class _FakeGoogleSignIn implements GoogleSignIn {
  String? initClientId;
  String? initServerClientId;
  int initializeCalls = 0;
  int authenticateCalls = 0;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializeCalls++;
    initClientId = clientId;
    initServerClientId = serverClientId;
  }

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    authenticateCalls++;
    throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _webClientId = 'web-client.apps.googleusercontent.com';
const _iosClientId = 'ios-client.apps.googleusercontent.com';

void main() {
  late _FakeGoogleSignIn google;

  setUp(() => google = _FakeGoogleSignIn());

  test('serverClientId — web-клиент, clientId — iOS-клиент', () async {
    final provider = GoogleAuthProvider(
      googleSignIn: google,
      serverClientId: _webClientId,
      iosClientId: _iosClientId,
    );

    await expectLater(
      provider.signIn(),
      throwsA(isA<SocialSignInCancelledFailure>()),
    );

    expect(google.initServerClientId, _webClientId);
    expect(google.initClientId, _iosClientId);
    expect(google.authenticateCalls, 1);
  });

  test('инициализация один раз на несколько попыток входа', () async {
    final provider = GoogleAuthProvider(
      googleSignIn: google,
      serverClientId: _webClientId,
      iosClientId: _iosClientId,
    );

    for (var i = 0; i < 2; i++) {
      await expectLater(
        provider.signIn(),
        throwsA(isA<SocialSignInCancelledFailure>()),
      );
    }

    expect(google.initializeCalls, 1);
    expect(google.authenticateCalls, 2);
  });

  test('плейсхолдер вместо web-клиента: вход недоступен, SDK не трогаем', () async {
    final provider = GoogleAuthProvider(
      googleSignIn: google,
      serverClientId: SocialAuthConfig.googleServerClientIdPlaceholder,
      iosClientId: _iosClientId,
    );

    await expectLater(
      provider.signIn(),
      throwsA(isA<SocialSignInUnavailableFailure>()),
    );

    expect(google.initializeCalls, 0);
  });

  test('плейсхолдер iOS-клиента не уходит в SDK как clientId', () async {
    final provider = GoogleAuthProvider(
      googleSignIn: google,
      serverClientId: _webClientId,
      iosClientId: SocialAuthConfig.googleIosClientIdPlaceholder,
    );

    await expectLater(
      provider.signIn(),
      throwsA(isA<SocialSignInCancelledFailure>()),
    );

    expect(google.initClientId, isNull);
    expect(google.initServerClientId, _webClientId);
  });
}
