import 'package:google_sign_in/google_sign_in.dart';
import 'package:mentorix_app/core/config/social_auth_config.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';

/// Вход через Google (`google_sign_in` 7.x). Бэкенду уходит `id_token`.
///
/// `serverClientId` — **всегда web-клиент**, на обеих платформах: поэтому `aud`
/// в токене одинаковый на iOS и Android. `clientId` (iOS-клиент) нужен только
/// iOS; Android его не использует.
class GoogleAuthProvider implements SocialAuthProvider {
  GoogleAuthProvider({
    GoogleSignIn? googleSignIn,
    String? serverClientId,
    String? iosClientId,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _serverClientId = serverClientId ?? SocialAuthConfig.googleServerClientId,
       _iosClientId = iosClientId ?? SocialAuthConfig.googleIosClientId;

  final GoogleSignIn _googleSignIn;
  final String _serverClientId;
  final String _iosClientId;
  Future<void>? _initialization;

  @override
  bool get isAvailable => true;

  @override
  Future<SocialCredential> signIn() async {
    final isConfigured = SocialAuthConfig.isRealClientId(
      _serverClientId,
      SocialAuthConfig.googleServerClientIdPlaceholder,
    );
    if (!isConfigured) throw const SocialSignInUnavailableFailure();

    try {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        // Обычно — не задан serverClientId (web-клиент).
        throw const SocialSignInUnavailableFailure();
      }
      return SocialCredential(idToken: idToken);
    } on GoogleSignInException catch (e, st) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          throw const SocialSignInCancelledFailure();
        default:
          AppLogger.error('google sign-in failed: ${e.code.name}', e, st);
          throw const SocialSignInUnavailableFailure();
      }
    }
  }

  Future<void> _ensureInitialized() {
    final hasIosClientId = SocialAuthConfig.isRealClientId(
      _iosClientId,
      SocialAuthConfig.googleIosClientIdPlaceholder,
    );

    return _initialization ??= _googleSignIn
        .initialize(
          clientId: hasIosClientId ? _iosClientId : null,
          serverClientId: _serverClientId,
        )
        // Неудачную инициализацию не запоминаем: следующая попытка повторит.
        .onError((error, stackTrace) {
          _initialization = null;
          Error.throwWithStackTrace(error!, stackTrace);
        });
  }
}
