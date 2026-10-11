import 'package:flutter/foundation.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Вход через Apple. Только iOS и macOS: на Android нужен веб-поток со
/// Service ID и redirect URI, которых в проекте нет — кнопка там скрыта.
class AppleAuthProvider implements SocialAuthProvider {
  @override
  bool get isAvailable =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Future<SocialCredential> signIn() async {
    if (!isAvailable) throw const SocialSignInUnavailableFailure();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

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

      return SocialCredential(
        idToken: idToken,
        name: name.isEmpty ? null : name,
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
