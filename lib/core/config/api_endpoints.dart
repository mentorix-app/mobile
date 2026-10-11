/// Пути API относительно `ApiConfig.baseUrl`. Литералы вида `'/auth/...'`
/// в остальном коде не пишутся — только отсюда.
///
/// Контракт: `docs/auth_api.md`.
abstract final class ApiEndpoints {
  // --- авторизация -----------------------------------------------------------

  /// `POST` — вход через Google. Публичный.
  static const authGoogle = '/auth/google';

  /// `POST` — вход через Apple. Публичный.
  static const authApple = '/auth/apple';

  /// `POST` — обновление токенов. Публичный, refresh-токен одноразовый.
  static const authRefresh = '/auth/refresh';

  /// `POST` — завершение сессии по refresh-токену. Публичный.
  static const authLogout = '/auth/logout';

  /// `POST` (Bearer) — завершение всех сессий пользователя.
  static const authLogoutAll = '/auth/logout-all';

  /// `GET` / `PATCH` (Bearer) — профиль.
  static const authMe = '/auth/me';

  /// `POST` (Bearer) — привязка Telegram по коду от бота.
  static const authTelegramLink = '/auth/telegram/link';

  // --- клиент ----------------------------------------------------------------

  /// `POST` (Bearer) — принять приглашение тренера (токен, `inv_…` или ссылка).
  static const clientInviteAccept = '/client/invites/accept';
}
