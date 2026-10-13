import 'package:dio/dio.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

/// Разбор, специфичный для эндпоинта: один и тот же `code` или статус на разных
/// эндпоинтах значит разное (401 `invalid_id_token` на входе — «токен не принят»,
/// на удалении аккаунта — «повторите окно Apple»). `null` — «не знаю», решает
/// общий разбор по `code` и статусу.
typedef EndpointFailureMapper = AuthFailure? Function(int status, String? code);

/// Ошибка API → доменный [AuthFailure].
///
/// Ветвление — **только по `code`** из тела ответа (`{"code","message"}`):
/// `message` бэкенд вправе менять, поэтому он не разбирается и пользователю не
/// показывается. Если `code` неизвестен (в том числе имена статусов вроде
/// `bad_request`), ошибка разбирается по HTTP-статусу.
abstract final class AuthErrorMapper {
  static const _networkTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  /// В debug-сборке к ошибке прикладывается статус и `code` ответа
  /// ([ApiErrorDetails]) — они показываются рядом с текстом. В release
  /// `details` не создаётся вовсе.
  static AuthFailure map(DioException e, {EndpointFailureMapper? endpoint}) {
    final failure = _resolve(e, endpoint);
    if (!DebugLog.enabled) return failure;

    final response = e.response;
    return failure.withDetails(
      ApiErrorDetails(
        status: response?.statusCode,
        code: ApiErrorCodes.of(response),
        transport: response == null ? e.type.name : null,
      ),
    );
  }

  static AuthFailure _resolve(DioException e, EndpointFailureMapper? endpoint) {
    if (e.error is SessionExpiredException) {
      return const SessionExpiredFailure();
    }

    if (_networkTypes.contains(e.type)) return const NetworkFailure();

    final status = e.response?.statusCode;
    if (status == null) return const UnknownFailure();

    final code = ApiErrorCodes.of(e.response);

    final specific = endpoint?.call(status, code);
    if (specific != null) return specific;

    final byCode = code == null ? null : fromCode(code);
    if (byCode != null) return byCode;

    return _fromStatus(status);
  }

  /// Известный `code` → ошибка; неизвестный → `null`.
  static AuthFailure? fromCode(String code) => switch (code) {
    // общие
    ApiErrorCodes.rateLimited => const TooManyRequestsFailure(),
    ApiErrorCodes.invalidIdToken => const SocialTokenRejectedFailure(),
    ApiErrorCodes.missingAuthorization ||
    ApiErrorCodes.invalidToken ||
    ApiErrorCodes.invalidRefreshToken => const SessionExpiredFailure(),
    ApiErrorCodes.userNotFound => const AccountNotFoundFailure(),
    ApiErrorCodes.providerNotConfigured => const ServerUnavailableFailure(),
    // привязка Telegram
    ApiErrorCodes.invalidLinkCode => const TelegramCodeInvalidFailure(),
    ApiErrorCodes.telegramLinkConflict => const TelegramLinkConflictFailure(),
    ApiErrorCodes.telegramAlreadyLinked => const TelegramAlreadyLinkedFailure(),
    // приглашения
    ApiErrorCodes.inviteNotFound => const InviteNotFoundFailure(),
    ApiErrorCodes.inviteExpired => const InviteExpiredFailure(),
    ApiErrorCodes.inviteConsumed => const InviteAlreadyConsumedFailure(),
    ApiErrorCodes.clientLimitReached => const InviteClientLimitReachedFailure(),
    ApiErrorCodes.selfInvite ||
    ApiErrorCodes.clientBlocked => const InviteNotAllowedFailure(),
    ApiErrorCodes.adminCannotAccept => const AdminAccountFailure(),
    _ => null,
  };

  /// Общий текст по статусу, когда `code` неизвестен.
  static AuthFailure _fromStatus(int status) => switch (status) {
    // На 429 ничего автоматически не повторяется — только сообщаем.
    429 => const TooManyRequestsFailure(),
    503 => const ServerUnavailableFailure(),
    400 => const InvalidRequestFailure(),
    401 => const SessionExpiredFailure(),
    _ => const UnknownFailure(),
  };

  /// `/auth/google`, `/auth/apple`: 401 без известного `code` — токен
  /// провайдера не принят (сессии на входе ещё нет, истекать нечему).
  static AuthFailure? socialSignIn(int status, String? code) =>
      status == 401 ? const SocialTokenRejectedFailure() : null;

  /// `DELETE /auth/me`. `user_not_found` здесь не разбирается: репозиторий
  /// считает его успехом (аккаунт уже удалён).
  static AuthFailure? accountDeletion(int status, String? code) {
    return switch (code) {
      ApiErrorCodes.appleAuthorizationRequired =>
        const AppleAuthorizationRequiredFailure(),
      ApiErrorCodes.invalidIdToken ||
      ApiErrorCodes.invalidAppleAuthorizationCode =>
        const AppleProofRejectedFailure(),
      ApiErrorCodes.appleAccountMismatch =>
        const AppleAccountMismatchFailure(),
      ApiErrorCodes.accountDeletionUnavailable =>
        const AccountDeletionUnavailableFailure(),
      ApiErrorCodes.appleRevocationFailed ||
      ApiErrorCodes.providerNotConfigured =>
        const AccountDeletionFailedFailure(),
      _ => status == 502 || status == 503
          ? const AccountDeletionFailedFailure()
          : null,
    };
  }
}
