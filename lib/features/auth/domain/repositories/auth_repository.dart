import 'package:mentorix_app/features/auth/domain/entities/invite_acceptance.dart';
import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
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

  /// `GET /client/trainers` — вызывается после [getProfile]. Пустой список —
  /// тренера нет, нужно показать экран приглашения.
  Future<List<LinkedTrainer>> getTrainers();

  /// Заменяет **оба** токена (и `user_id`: он может поменяться) и сбрасывает
  /// кеш профиля. После вызова нужно заново запросить профиль.
  Future<void> linkTelegram(String code);

  Future<InviteAcceptance> acceptInvite(String tokenOrLink);

  /// `DELETE /auth/me`. Сначала без тела; если у аккаунта есть вход через Apple
  /// (422 `apple_authorization_required`), показывает окно Apple и повторяет с
  /// его данными, взятыми прямо перед запросом. [confirmWithApple] — сразу
  /// показать окно Apple (повтор после отказа Apple). Успех (204 и 404
  /// `user_not_found`) очищает токены и отключает Google.
  ///
  /// Бросает [AuthFailure]; [SocialSignInCancelledFailure] — пользователь закрыл
  /// окно Apple, аккаунт не тронут.
  Future<void> deleteAccount({bool confirmWithApple = false});

  /// Завершает сессию на сервере (если получится) и локально.
  /// Локальная сессия очищается в любом случае.
  Future<void> logout();

  Future<void> logoutAll();

  /// Токены и кеш профиля — локально, без запросов.
  Future<void> clearLocalSession();
}
