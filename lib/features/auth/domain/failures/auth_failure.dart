/// Доменные ошибки авторизации. Текста здесь нет: пользователю сообщение
/// подставляет слой представления по типу ошибки.
sealed class AuthFailure implements Exception {
  const AuthFailure();
}

// --- общие -----------------------------------------------------------------

/// Нет связи, таймаут соединения или ответа.
final class NetworkFailure extends AuthFailure {
  const NetworkFailure();
}

/// 503 (в том числе `provider_not_configured`): вход или привязка ещё не
/// настроены на сервере либо временно недоступны.
final class ServerUnavailableFailure extends AuthFailure {
  const ServerUnavailableFailure();
}

/// 429. Автоматически ничего не повторяется.
final class TooManyRequestsFailure extends AuthFailure {
  const TooManyRequestsFailure();
}

/// Refresh вернул 401 или обновлять нечем: нужен вход.
final class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure();
}

/// 400 без более точного смысла (`bad_request` и неизвестный `code`).
final class InvalidRequestFailure extends AuthFailure {
  const InvalidRequestFailure();
}

final class UnknownFailure extends AuthFailure {
  const UnknownFailure();
}

// --- вход через Google и Apple ---------------------------------------------

/// `invalid_id_token`: сервер не принял `id_token` Google или Apple.
final class SocialTokenRejectedFailure extends AuthFailure {
  const SocialTokenRejectedFailure();
}

/// Пользователь закрыл окно входа. Ошибкой для него не является.
final class SocialSignInCancelledFailure extends AuthFailure {
  const SocialSignInCancelledFailure();
}

/// Провайдер входа.
enum SocialProvider { google, apple }

/// Идентификаторы провайдера не заданы (пусты или плейсхолдеры): приложение
/// запущено без `--dart-define-from-file=config/stage.json`. Это ошибка запуска,
/// а не сбой провайдера или бэкенда, поэтому отделена от
/// [SocialSignInUnavailableFailure].
final class SocialSignInNotConfiguredFailure extends AuthFailure {
  const SocialSignInNotConfiguredFailure({this.provider = SocialProvider.google});

  final SocialProvider provider;
}

/// Apple вернула не тот `state`, что мы передали: ответ мог быть подменён,
/// токен на сервер не отправляется.
final class SocialSignInStateMismatchFailure extends AuthFailure {
  const SocialSignInStateMismatchFailure();
}

/// Провайдер не поддерживается на платформе или не вернул токен.
final class SocialSignInUnavailableFailure extends AuthFailure {
  const SocialSignInUnavailableFailure();
}

// --- Telegram --------------------------------------------------------------

/// 400 `invalid_link_code`: код неверный, просрочен или уже использован.
final class TelegramCodeInvalidFailure extends AuthFailure {
  const TelegramCodeInvalidFailure();
}

/// 404 `user_not_found`: учётной записи больше нет.
final class AccountNotFoundFailure extends AuthFailure {
  const AccountNotFoundFailure();
}

/// 409 `telegram_link_conflict`: этот Telegram принадлежит аккаунту, который
/// нельзя объединить с текущим.
final class TelegramLinkConflictFailure extends AuthFailure {
  const TelegramLinkConflictFailure();
}

/// 409 `telegram_already_linked`: у аккаунта уже привязан другой Telegram.
final class TelegramAlreadyLinkedFailure extends AuthFailure {
  const TelegramAlreadyLinkedFailure();
}

// --- приглашения -----------------------------------------------------------

/// 404 `invite_not_found`.
final class InviteNotFoundFailure extends AuthFailure {
  const InviteNotFoundFailure();
}

/// 410 `invite_expired`.
final class InviteExpiredFailure extends AuthFailure {
  const InviteExpiredFailure();
}

/// 409 `invite_consumed`: использовано другим человеком.
final class InviteAlreadyConsumedFailure extends AuthFailure {
  const InviteAlreadyConsumedFailure();
}

/// 409 `client_limit_reached`: у тренера нет свободных мест.
final class InviteClientLimitReachedFailure extends AuthFailure {
  const InviteClientLimitReachedFailure();
}

/// 422 `self_invite` или `client_blocked`: своё приглашение или тренер
/// заблокировал клиента.
final class InviteNotAllowedFailure extends AuthFailure {
  const InviteNotAllowedFailure();
}

/// 403 `admin_cannot_accept`: учётная запись администратора.
final class AdminAccountFailure extends AuthFailure {
  const AdminAccountFailure();
}

/// Код привязки Telegram одноразовый: после любого ответа сервера, кроме 429 и
/// 401, он потрачен. Ошибка без ответа сервера (нет связи) код не тратит.
///
/// Список исчерпывающий: новый подтип не компилируется, пока для него не решено,
/// тратится ли код.
extension TelegramCodeSpending on AuthFailure {
  bool get spendsTelegramCode => switch (this) {
    TelegramCodeInvalidFailure() ||
    AccountNotFoundFailure() ||
    TelegramLinkConflictFailure() ||
    TelegramAlreadyLinkedFailure() ||
    ServerUnavailableFailure() ||
    InvalidRequestFailure() ||
    UnknownFailure() => true,
    NetworkFailure() ||
    TooManyRequestsFailure() ||
    SessionExpiredFailure() ||
    SocialTokenRejectedFailure() ||
    SocialSignInCancelledFailure() ||
    SocialSignInStateMismatchFailure() ||
    SocialSignInNotConfiguredFailure() ||
    SocialSignInUnavailableFailure() ||
    InviteNotFoundFailure() ||
    InviteExpiredFailure() ||
    InviteAlreadyConsumedFailure() ||
    InviteClientLimitReachedFailure() ||
    InviteNotAllowedFailure() ||
    AdminAccountFailure() => false,
  };
}
