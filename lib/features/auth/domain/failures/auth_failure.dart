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

/// 503: вход или привязка ещё не настроены на сервере либо временно недоступны.
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

/// 400 без более точного смысла.
final class InvalidRequestFailure extends AuthFailure {
  const InvalidRequestFailure();
}

final class UnknownFailure extends AuthFailure {
  const UnknownFailure();
}

// --- вход через Google и Apple ---------------------------------------------

/// 401 на `/auth/google` и `/auth/apple`: сервер не принял `id_token`.
final class SocialTokenRejectedFailure extends AuthFailure {
  const SocialTokenRejectedFailure();
}

/// Пользователь закрыл окно входа. Ошибкой для него не является.
final class SocialSignInCancelledFailure extends AuthFailure {
  const SocialSignInCancelledFailure();
}

/// Провайдер не настроен (плейсхолдеры client id), не поддерживается
/// на платформе или не вернул токен.
final class SocialSignInUnavailableFailure extends AuthFailure {
  const SocialSignInUnavailableFailure();
}

// --- Telegram --------------------------------------------------------------

/// 400: код неверный, просрочен или уже использован.
final class TelegramCodeInvalidFailure extends AuthFailure {
  const TelegramCodeInvalidFailure();
}

/// 404: учётной записи больше нет.
final class AccountNotFoundFailure extends AuthFailure {
  const AccountNotFoundFailure();
}

/// 409: записи нельзя объединить либо к этой уже привязан другой Telegram.
///
/// Два случая различаются только текстом ответа, поэтому он сохраняется в
/// [message] и показывается как есть (исключение из правила «текст бэкенда
/// пользователю не показывается»), пока у бэкенда нет поля `code`.
final class TelegramLinkConflictFailure extends AuthFailure {
  const TelegramLinkConflictFailure({this.message});

  final String? message;
}

// --- приглашения -----------------------------------------------------------

final class InviteNotFoundFailure extends AuthFailure {
  const InviteNotFoundFailure();
}

/// 410.
final class InviteExpiredFailure extends AuthFailure {
  const InviteExpiredFailure();
}

/// 409 `invite already consumed`: использовано другим человеком.
final class InviteAlreadyConsumedFailure extends AuthFailure {
  const InviteAlreadyConsumedFailure();
}

/// 409 `client limit reached`: у тренера нет свободных мест.
final class InviteClientLimitReachedFailure extends AuthFailure {
  const InviteClientLimitReachedFailure();
}

/// 409 с текстом, которого в контракте нет.
final class InviteConflictFailure extends AuthFailure {
  const InviteConflictFailure();
}

/// 422: своё приглашение или тренер заблокировал клиента.
final class InviteNotAllowedFailure extends AuthFailure {
  const InviteNotAllowedFailure();
}

/// 403: учётная запись администратора.
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
    ServerUnavailableFailure() ||
    InvalidRequestFailure() ||
    UnknownFailure() => true,
    NetworkFailure() ||
    TooManyRequestsFailure() ||
    SessionExpiredFailure() ||
    SocialTokenRejectedFailure() ||
    SocialSignInCancelledFailure() ||
    SocialSignInUnavailableFailure() ||
    InviteNotFoundFailure() ||
    InviteExpiredFailure() ||
    InviteAlreadyConsumedFailure() ||
    InviteClientLimitReachedFailure() ||
    InviteConflictFailure() ||
    InviteNotAllowedFailure() ||
    AdminAccountFailure() => false,
  };
}
