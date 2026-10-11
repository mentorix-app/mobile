/// Ключи локального хранилища — единственное место, где они записаны.
///
/// Строковых литералов ключей в остальном коде нет: опечатка в одном месте
/// иначе даёт «пустое» чтение без ошибки, а переименование требует поиска
/// по всему проекту.
abstract final class StorageKeys {
  // --- shared_preferences: не секреты, читаются часто ------------------------

  /// Выбранный режим темы: `system`, `light` или `dark`.
  static const themeMode = 'theme_mode';

  /// Флаг первой установки. Лежит в `shared_preferences`, потому что при
  /// удалении приложения он стирается, а Keychain на iOS — нет: нет флага —
  /// токены прошлой установки удаляются.
  static const secureStorageInstallFlag = 'secure_storage_install_flag';

  /// Предложение привязать Telegram закрыто для пользователя [userId].
  static String onboardingTelegramOfferDone(String userId) =>
      'onboarding_telegram_offer_done_$userId';

  /// Шаг приглашения пройден или отложен для пользователя [userId].
  static String onboardingInviteDone(String userId) =>
      'onboarding_invite_done_$userId';

  // --- flutter_secure_storage: секреты и персональные данные -----------------

  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
  static const expiresAt = 'expires_at';
  static const userId = 'user_id';

  /// Имя из Apple, которое ещё не принял бэкенд.
  static const pendingAppleName = 'pending_apple_name';

  /// Всё, что относится к сессии: очищается целиком при её окончании.
  static const sessionTokens = [accessToken, refreshToken, expiresAt, userId];
}
