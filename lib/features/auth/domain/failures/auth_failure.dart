/// Что сервер ответил на самом деле: для диагностики в debug-сборке.
///
/// Заполняется только в debug (`AuthErrorMapper`), в release всегда `null`.
/// Решений по нему не принимается — только показ рядом с текстом ошибки.
class ApiErrorDetails {
  const ApiErrorDetails({this.status, this.code, this.transport});

  /// HTTP-статус; `null`, если ответа не было.
  final int? status;

  /// `code` из тела ответа.
  final String? code;

  /// Тип сбоя без ответа сервера (`connectionError`, `receiveTimeout`, …).
  final String? transport;

  /// `503 provider_not_configured`, `404`, `connectionError`.
  String get summary =>
      [?status, ?code, ?transport].map((part) => '$part').join(' ');
}

/// Доменные ошибки авторизации. Текста здесь нет: пользователю сообщение
/// подставляет слой представления по типу ошибки.
sealed class AuthFailure implements Exception {
  const AuthFailure({this.details});

  /// Ответ сервера для debug-показа; в release `null`.
  final ApiErrorDetails? details;
}

// --- общие -----------------------------------------------------------------

/// Нет связи, таймаут соединения или ответа.
final class NetworkFailure extends AuthFailure {
  const NetworkFailure({super.details});
}

/// 503 (в том числе `provider_not_configured`): вход или привязка ещё не
/// настроены на сервере либо временно недоступны.
final class ServerUnavailableFailure extends AuthFailure {
  const ServerUnavailableFailure({super.details});
}

/// 429. Автоматически ничего не повторяется.
final class TooManyRequestsFailure extends AuthFailure {
  const TooManyRequestsFailure({super.details});
}

/// Refresh вернул 401 или обновлять нечем: нужен вход.
final class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure({super.details});
}

/// 400 без более точного смысла (`bad_request` и неизвестный `code`).
final class InvalidRequestFailure extends AuthFailure {
  const InvalidRequestFailure({super.details});
}

final class UnknownFailure extends AuthFailure {
  const UnknownFailure({super.details});
}

// --- вход через Google и Apple ---------------------------------------------

/// `invalid_id_token`: сервер не принял `id_token` Google или Apple.
final class SocialTokenRejectedFailure extends AuthFailure {
  const SocialTokenRejectedFailure({super.details});
}

/// Пользователь закрыл окно входа. Ошибкой для него не является.
final class SocialSignInCancelledFailure extends AuthFailure {
  const SocialSignInCancelledFailure({super.details});
}

/// Провайдер входа.
enum SocialProvider { google, apple }

/// Идентификаторы провайдера не заданы (пусты или плейсхолдеры): приложение
/// запущено без `--dart-define-from-file=config/stage.json`. Это ошибка запуска,
/// а не сбой провайдера или бэкенда, поэтому отделена от
/// [SocialSignInUnavailableFailure].
final class SocialSignInNotConfiguredFailure extends AuthFailure {
  const SocialSignInNotConfiguredFailure({
    this.provider = SocialProvider.google,
    super.details,
  });

  final SocialProvider provider;
}

/// Apple вернула не тот `state`, что мы передали: ответ мог быть подменён,
/// токен на сервер не отправляется.
final class SocialSignInStateMismatchFailure extends AuthFailure {
  const SocialSignInStateMismatchFailure({super.details});
}

/// Провайдер не поддерживается на платформе или не вернул токен.
final class SocialSignInUnavailableFailure extends AuthFailure {
  const SocialSignInUnavailableFailure({super.details});
}

// --- Telegram --------------------------------------------------------------

/// 400 `invalid_link_code`: код неверный, просрочен или уже использован.
final class TelegramCodeInvalidFailure extends AuthFailure {
  const TelegramCodeInvalidFailure({super.details});
}

/// 404 `user_not_found`: учётной записи больше нет.
final class AccountNotFoundFailure extends AuthFailure {
  const AccountNotFoundFailure({super.details});
}

/// 409 `telegram_link_conflict`: этот Telegram принадлежит аккаунту, который
/// нельзя объединить с текущим.
final class TelegramLinkConflictFailure extends AuthFailure {
  const TelegramLinkConflictFailure({super.details});
}

/// 409 `telegram_already_linked`: у аккаунта уже привязан другой Telegram.
final class TelegramAlreadyLinkedFailure extends AuthFailure {
  const TelegramAlreadyLinkedFailure({super.details});
}

// --- приглашения -----------------------------------------------------------

/// 404 `invite_not_found`.
final class InviteNotFoundFailure extends AuthFailure {
  const InviteNotFoundFailure({super.details});
}

/// 410 `invite_expired`.
final class InviteExpiredFailure extends AuthFailure {
  const InviteExpiredFailure({super.details});
}

/// 409 `invite_consumed`: использовано другим человеком.
final class InviteAlreadyConsumedFailure extends AuthFailure {
  const InviteAlreadyConsumedFailure({super.details});
}

/// 409 `client_limit_reached`: у тренера нет свободных мест.
final class InviteClientLimitReachedFailure extends AuthFailure {
  const InviteClientLimitReachedFailure({super.details});
}

/// 422 `self_invite` или `client_blocked`: своё приглашение или тренер
/// заблокировал клиента.
final class InviteNotAllowedFailure extends AuthFailure {
  const InviteNotAllowedFailure({super.details});
}

/// 403 `admin_cannot_accept`: учётная запись администратора.
final class AdminAccountFailure extends AuthFailure {
  const AdminAccountFailure({super.details});
}

// --- удаление аккаунта -------------------------------------------------------

/// 422 `apple_authorization_required`: у аккаунта есть вход через Apple, а в
/// запросе нет данных Apple. Репозиторий сам показывает окно Apple и повторяет;
/// наружу выходит, только если сервер потребовал это и со вторым запросом.
final class AppleAuthorizationRequiredFailure extends AuthFailure {
  const AppleAuthorizationRequiredFailure({super.details});
}

/// 401 `invalid_id_token` или 400 `invalid_apple_authorization_code` на
/// удалении: токен Apple не прошёл проверку либо код просрочен или использован.
/// Нужно показать окно Apple заново.
final class AppleProofRejectedFailure extends AuthFailure {
  const AppleProofRejectedFailure({super.details});
}

/// 403 `apple_account_mismatch`: вошли не тем Apple ID, которым создан аккаунт.
final class AppleAccountMismatchFailure extends AuthFailure {
  const AppleAccountMismatchFailure({super.details});
}

/// 409 `account_deletion_unavailable`: у аккаунта есть роль тренера или
/// администратора — удаление только через поддержку.
final class AccountDeletionUnavailableFailure extends AuthFailure {
  const AccountDeletionUnavailableFailure({super.details});
}

/// 502 `apple_revocation_failed`, 503 (в том числе `provider_not_configured`):
/// аккаунт не удалён, попробовать позже.
final class AccountDeletionFailedFailure extends AuthFailure {
  const AccountDeletionFailedFailure({super.details});
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
    AdminAccountFailure() ||
    AppleAuthorizationRequiredFailure() ||
    AppleProofRejectedFailure() ||
    AppleAccountMismatchFailure() ||
    AccountDeletionUnavailableFailure() ||
    AccountDeletionFailedFailure() => false,
  };
}

/// Копия ошибки с [details]. Список исчерпывающий: новый подтип не
/// компилируется, пока не решено, как его копировать.
extension AuthFailureDetails on AuthFailure {
  AuthFailure withDetails(ApiErrorDetails? details) {
    if (details == null) return this;

    return switch (this) {
      NetworkFailure() => NetworkFailure(details: details),
      ServerUnavailableFailure() => ServerUnavailableFailure(details: details),
      TooManyRequestsFailure() => TooManyRequestsFailure(details: details),
      SessionExpiredFailure() => SessionExpiredFailure(details: details),
      InvalidRequestFailure() => InvalidRequestFailure(details: details),
      UnknownFailure() => UnknownFailure(details: details),
      SocialTokenRejectedFailure() => SocialTokenRejectedFailure(
        details: details,
      ),
      SocialSignInCancelledFailure() => SocialSignInCancelledFailure(
        details: details,
      ),
      SocialSignInNotConfiguredFailure(:final provider) =>
        SocialSignInNotConfiguredFailure(provider: provider, details: details),
      SocialSignInStateMismatchFailure() => SocialSignInStateMismatchFailure(
        details: details,
      ),
      SocialSignInUnavailableFailure() => SocialSignInUnavailableFailure(
        details: details,
      ),
      TelegramCodeInvalidFailure() => TelegramCodeInvalidFailure(
        details: details,
      ),
      AccountNotFoundFailure() => AccountNotFoundFailure(details: details),
      TelegramLinkConflictFailure() => TelegramLinkConflictFailure(
        details: details,
      ),
      TelegramAlreadyLinkedFailure() => TelegramAlreadyLinkedFailure(
        details: details,
      ),
      InviteNotFoundFailure() => InviteNotFoundFailure(details: details),
      InviteExpiredFailure() => InviteExpiredFailure(details: details),
      InviteAlreadyConsumedFailure() => InviteAlreadyConsumedFailure(
        details: details,
      ),
      InviteClientLimitReachedFailure() => InviteClientLimitReachedFailure(
        details: details,
      ),
      InviteNotAllowedFailure() => InviteNotAllowedFailure(details: details),
      AdminAccountFailure() => AdminAccountFailure(details: details),
      AppleAuthorizationRequiredFailure() => AppleAuthorizationRequiredFailure(
        details: details,
      ),
      AppleProofRejectedFailure() => AppleProofRejectedFailure(
        details: details,
      ),
      AppleAccountMismatchFailure() => AppleAccountMismatchFailure(
        details: details,
      ),
      AccountDeletionUnavailableFailure() =>
        AccountDeletionUnavailableFailure(details: details),
      AccountDeletionFailedFailure() => AccountDeletionFailedFailure(
        details: details,
      ),
    };
  }
}
