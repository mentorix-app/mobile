import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Локализованный текст для пользователя. Сырой текст бэкенда сюда не попадает.
extension AuthFailureMessage on AuthFailure {
  String message(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    ServerUnavailableFailure() => l10n.errorServerUnavailable,
    TooManyRequestsFailure() => l10n.errorTooManyRequests,
    SessionExpiredFailure() => l10n.errorSessionExpired,
    InvalidRequestFailure() => l10n.errorInvalidRequest,
    UnknownFailure() => l10n.errorUnknown,
    SocialTokenRejectedFailure() => l10n.errorSocialRejected,
    SocialSignInUnavailableFailure() => l10n.errorSocialUnavailable,
    // Отказ пользователя ошибкой не показывается; строка — на случай вызова.
    SocialSignInCancelledFailure() => l10n.errorUnknown,
    TelegramCodeInvalidFailure() => l10n.errorTelegramCodeInvalid,
    AccountNotFoundFailure() => l10n.errorAccountNotFound,
    TelegramLinkConflictFailure() => l10n.errorTelegramConflict,
    InviteNotFoundFailure() => l10n.errorInviteNotFound,
    InviteExpiredFailure() => l10n.errorInviteExpired,
    InviteAlreadyConsumedFailure() => l10n.errorInviteConsumed,
    InviteClientLimitReachedFailure() => l10n.errorInviteClientLimit,
    InviteConflictFailure() => l10n.errorInviteConflict,
    InviteNotAllowedFailure() => l10n.errorInviteNotAllowed,
    AdminAccountFailure() => l10n.errorAdminAccount,
  };
}
