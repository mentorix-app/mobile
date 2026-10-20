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

  /// `GET` (Bearer) — тренеры клиента: `{"items": [...]}`, пустой массив —
  /// тренера нет. Вызывается после `GET /auth/me`.
  static const clientTrainers = '/client/trainers';

  /// `GET` (Bearer) — программа клиента у тренера: назначение, недели, дни,
  /// блоки, `completed_days`. Контракт: `docs/backend_client_api.md`.
  static String clientTrainerProgram(String trainerId) =>
      '/client/trainers/$trainerId/program';

  /// `POST` — возврат из веб-потока Apple на Android (Return URL Services ID).
  /// Сессию не создаёт: приложение после возврата само шлёт `id_token`.
  static const authAppleCallback = '/auth/apple/callback';
}
