import 'package:dio/dio.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

/// Запасной разбор эндпоинта по статусу, когда `code` не распознан.
/// `null` — «не знаю», решает общий разбор по статусу.
typedef EndpointFailureMapper = AuthFailure? Function(int status);

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

  static AuthFailure map(DioException e, {EndpointFailureMapper? endpoint}) {
    if (e.error is SessionExpiredException) {
      return const SessionExpiredFailure();
    }

    if (_networkTypes.contains(e.type)) return const NetworkFailure();

    final status = e.response?.statusCode;
    if (status == null) return const UnknownFailure();

    final code = ApiErrorCodes.of(e.response);
    final byCode = code == null ? null : fromCode(code);
    if (byCode != null) return byCode;

    return _fromStatus(status, endpoint);
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
  static AuthFailure _fromStatus(int status, EndpointFailureMapper? endpoint) {
    // На 429 ничего автоматически не повторяется — только сообщаем.
    if (status == 429) return const TooManyRequestsFailure();
    if (status == 503) return const ServerUnavailableFailure();

    final specific = endpoint?.call(status);
    if (specific != null) return specific;

    return switch (status) {
      400 => const InvalidRequestFailure(),
      401 => const SessionExpiredFailure(),
      _ => const UnknownFailure(),
    };
  }

  /// `/auth/google`, `/auth/apple`: 401 без известного `code` — токен
  /// провайдера не принят (сессии на входе ещё нет, истекать нечему).
  static AuthFailure? socialSignIn(int status) =>
      status == 401 ? const SocialTokenRejectedFailure() : null;
}
