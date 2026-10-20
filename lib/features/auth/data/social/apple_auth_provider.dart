import 'package:flutter/foundation.dart';
import 'package:mentorix_app/core/config/social_auth_config.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/features/auth/data/social/sign_in_nonce.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Запрос учётных данных Apple; в проде — `SignInWithApple.getAppleIDCredential`.
typedef AppleCredentialRequest =
    Future<AuthorizationCredentialAppleID> Function({
      required List<AppleIDAuthorizationScopes> scopes,
      WebAuthenticationOptions? webAuthenticationOptions,
      String? nonce,
      String? state,
    });

/// Вход через Apple.
///
/// iOS и macOS — нативный диалог. Android — веб-поток со Services ID и
/// redirect URI на бэкенде (`/auth/apple/callback`), результат возвращается в
/// приложение через `SignInWithAppleCallback` из `AndroidManifest.xml`.
///
/// Перед каждым входом генерируется случайный `state`; ответ Apple принимается,
/// только если `state` в нём тот же. Иначе токен на сервер не уходит.
///
/// Вход (`signIn(withNonce: true)`) идёт с `nonce`: на каждую попытку новая
/// строка, Apple получает её SHA-256 (hex, нижний регистр) и кладёт в
/// `identityToken`, а исходная строка возвращается в [SocialCredential.nonce] и
/// уходит на бэкенд. Окно Apple при удалении аккаунта — без `nonce`.
class AppleAuthProvider implements SocialAuthProvider {
  AppleAuthProvider({
    AppleCredentialRequest? request,
    String Function()? stateGenerator,
    String Function()? nonceGenerator,
    TargetPlatform? platform,
    String? serviceId,
    String? redirectUri,
    void Function(String message)? onWarning,
  }) : _request = request ?? SignInWithApple.getAppleIDCredential,
       _generateState = stateGenerator ?? generateState,
       _generateNonce = nonceGenerator ?? SignInNonce.randomUrlSafe,
       _platform = platform,
       _serviceId = serviceId ?? SocialAuthConfig.appleServiceId,
       _redirectUri = redirectUri ?? SocialAuthConfig.appleRedirectUri,
       _warn = onWarning ?? AppLogger.warning;

  final AppleCredentialRequest _request;
  final String Function() _generateState;
  final String Function() _generateNonce;
  final TargetPlatform? _platform;
  final String _serviceId;
  final String _redirectUri;
  final void Function(String message) _warn;

  TargetPlatform get _target => _platform ?? defaultTargetPlatform;

  @override
  bool get isAvailable => switch (_target) {
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.android => true,
    _ => false,
  };

  /// Веб-поток Android не работает без Services ID и redirect URI.
  bool get _webFlowConfigured =>
      SocialAuthConfig.isRealClientId(
        _serviceId,
        SocialAuthConfig.appleServiceIdPlaceholder,
      ) &&
      SocialAuthConfig.isRealClientId(
        _redirectUri,
        SocialAuthConfig.appleRedirectUriPlaceholder,
      );

  /// 32 байта из `Random.secure()`, base64url без заполнения.
  @visibleForTesting
  static String generateState() => SignInNonce.randomUrlSafe();

  /// У Apple нечего отключать на устройстве: токены отзывает бэкенд.
  @override
  Future<void> disconnect() async {}

  @override
  Future<SocialCredential> signIn({bool withNonce = false}) async {
    if (!isAvailable) throw const SocialSignInUnavailableFailure();

    final isAndroid = _target == TargetPlatform.android;
    if (isAndroid && !_webFlowConfigured) {
      _warn(SocialAuthConfig.appleNotConfiguredWarning);
      throw const SocialSignInNotConfiguredFailure(
        provider: SocialProvider.apple,
      );
    }

    final state = _generateState();
    // Новое значение на каждую попытку, нигде не хранится.
    final nonce = withNonce ? SignInNonce(_generateNonce()) : null;

    try {
      final credential = await _request(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: isAndroid
            ? WebAuthenticationOptions(
                clientId: _serviceId,
                redirectUri: Uri.parse(_redirectUri),
              )
            : null,
        nonce: nonce?.hashed,
        state: state,
      );

      // Токен принимается только на тот запрос, который мы сами отправили.
      if (credential.state != state) {
        AppLogger.warning('apple sign-in: state mismatch, token dropped');
        throw const SocialSignInStateMismatchFailure();
      }

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialSignInUnavailableFailure();
      }

      // Имя Apple отдаёт только при первой авторизации.
      final name = [credential.givenName, credential.familyName]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');

      final authorizationCode = credential.authorizationCode;

      return SocialCredential(
        idToken: idToken,
        name: name.isEmpty ? null : name,
        authorizationCode: authorizationCode.isEmpty ? null : authorizationCode,
        // Только веб-поток Android: на iOS поле на бэкенд не уходит.
        webRedirectUri: isAndroid ? _redirectUri : null,
        nonce: nonce?.raw,
      );
    } on SignInWithAppleAuthorizationException catch (e, st) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelledFailure();
      }
      AppLogger.error('apple sign-in failed: ${e.code.name}', e, st);
      throw const SocialSignInUnavailableFailure();
    }
  }
}
