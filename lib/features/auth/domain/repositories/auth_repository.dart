import 'package:mentorix_app/features/auth/domain/entities/invite_acceptance.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';

/// Все методы бросают [AuthFailure].
abstract class AuthRepository {
  bool get isGoogleSignInAvailable;
  bool get isAppleSignInAvailable;

  /// Подготавливает хранилище (после переустановки стирает чужие токены)
  /// и сообщает, есть ли сохранённая сессия.
  Future<bool> restoreSession();

  /// Вход сохраняет токены. Профиль после этого запрашивается отдельно.
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();

  /// `GET /auth/me`. Профиль кешируется в памяти до [forceRefresh],
  /// привязки Telegram, выхода и конца сессии.
  Future<UserProfile> getProfile({bool forceRefresh = false});

  Future<UserProfile> updateName(String name);

  /// Заменяет **оба** токена (и `user_id`: он может поменяться) и сбрасывает
  /// кеш профиля. После вызова нужно заново запросить профиль.
  Future<void> linkTelegram(String code);

  Future<InviteAcceptance> acceptInvite(String tokenOrLink);

  /// Завершает сессию на сервере (если получится) и локально.
  /// Локальная сессия очищается в любом случае.
  Future<void> logout();

  Future<void> logoutAll();

  /// Токены и кеш профиля — локально, без запросов.
  Future<void> clearLocalSession();
}
