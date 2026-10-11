import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';

/// Получение `id_token` у внешнего провайдера. За интерфейсом спрятаны
/// конкретные SDK: репозиторий про них не знает.
abstract class SocialAuthProvider {
  /// Доступен ли провайдер на этой платформе (кнопка показывается только если да).
  bool get isAvailable;

  /// Бросает [SocialSignInCancelledFailure], если пользователь отказался,
  /// и [SocialSignInUnavailableFailure], если вход невозможен.
  Future<SocialCredential> signIn();
}
