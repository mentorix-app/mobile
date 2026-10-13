import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Локализованный текст для пользователя. Сырой текст бэкенда сюда не попадает.
extension AuthFailureMessage on AuthFailure {
  /// [debug] по умолчанию — debug-сборка. В ней «не настроено» объясняет, как
  /// запустить приложение, а к тексту добавляется ответ сервера:
  /// «Не удалось удалить аккаунт (503 provider_not_configured)». В release
  /// остаётся только обычный текст.
  String message(AppLocalizations l10n, {bool? debug}) {
    final isDebug = debug ?? DebugLog.enabled;
    final text = _text(l10n, isDebug);
    final info = isDebug ? details?.summary : null;

    return info == null || info.isEmpty ? text : '$text ($info)';
  }

  String _text(AppLocalizations l10n, bool debug) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    ServerUnavailableFailure() => l10n.errorServerUnavailable,
    TooManyRequestsFailure() => l10n.errorTooManyRequests,
    SessionExpiredFailure() => l10n.errorSessionExpired,
    InvalidRequestFailure() => l10n.errorInvalidRequest,
    UnknownFailure() => l10n.errorUnknown,
    SocialTokenRejectedFailure() => l10n.errorSocialRejected,
    SocialSignInNotConfiguredFailure(:final provider) =>
      debug
          ? switch (provider) {
              SocialProvider.google => l10n.errorGoogleNotConfigured,
              SocialProvider.apple => l10n.errorAppleNotConfigured,
            }
          : l10n.errorSocialUnavailable,
    SocialSignInStateMismatchFailure() => l10n.errorAppleStateMismatch,
    SocialSignInUnavailableFailure() => l10n.errorSocialUnavailable,
    // Отказ пользователя ошибкой не показывается; строка — на случай вызова.
    SocialSignInCancelledFailure() => l10n.errorUnknown,
    TelegramCodeInvalidFailure() => l10n.errorTelegramCodeInvalid,
    AccountNotFoundFailure() => l10n.errorAccountNotFound,
    TelegramLinkConflictFailure() => l10n.errorTelegramConflict,
    TelegramAlreadyLinkedFailure() => l10n.errorTelegramAlreadyLinked,
    InviteNotFoundFailure() => l10n.errorInviteNotFound,
    InviteExpiredFailure() => l10n.errorInviteExpired,
    InviteAlreadyConsumedFailure() => l10n.errorInviteConsumed,
    InviteClientLimitReachedFailure() => l10n.errorInviteClientLimit,
    InviteNotAllowedFailure() => l10n.errorInviteNotAllowed,
    AdminAccountFailure() => l10n.errorAdminAccount,
    AppleAuthorizationRequiredFailure() ||
    AppleProofRejectedFailure() => l10n.errorAppleConfirmationRetry,
    AppleAccountMismatchFailure() => l10n.errorAppleAccountMismatch,
    AccountDeletionUnavailableFailure() => l10n.errorAccountDeletionUnavailable,
    AccountDeletionFailedFailure() => l10n.errorAccountDeletionFailed,
  };
}
