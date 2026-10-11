import 'package:dio/dio.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/features/auth/data/mappers/invite_conflict_parser.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

/// Разбор ошибки конкретного эндпоинта: статус и `message` из ответа.
/// `null` — «не знаю», решает общий разбор.
typedef EndpointFailureMapper =
    AuthFailure? Function(int status, String? message);

abstract final class AuthErrorMapper {
  static const _networkTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  /// Общий разбор: сеть, 429 и 503 одинаковы для всех эндпоинтов,
  /// остальное — по [endpoint].
  static AuthFailure map(DioException e, {EndpointFailureMapper? endpoint}) {
    if (e.error is SessionExpiredException) {
      return const SessionExpiredFailure();
    }

    if (_networkTypes.contains(e.type)) return const NetworkFailure();

    final status = e.response?.statusCode;
    if (status == null) return const UnknownFailure();

    // На 429 ничего автоматически не повторяется — только сообщаем.
    if (status == 429) return const TooManyRequestsFailure();
    if (status == 503) return const ServerUnavailableFailure();

    final specific = endpoint?.call(status, messageOf(e.response));
    if (specific != null) return specific;

    return switch (status) {
      400 => const InvalidRequestFailure(),
      401 => const SessionExpiredFailure(),
      _ => const UnknownFailure(),
    };
  }

  /// `{ "message": "..." }` из тела ошибки. Пользователю не показывается —
  /// только для разбора и лога.
  static String? messageOf(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String) return message;
    }
    return null;
  }

  // --- разбор по эндпоинтам -------------------------------------------------

  /// `/auth/google`, `/auth/apple`.
  static AuthFailure? socialSignIn(int status, String? message) =>
      status == 401 ? const SocialTokenRejectedFailure() : null;

  /// `/auth/me`. 404 здесь — учётной записи больше нет: после переноса на
  /// старую запись прежние токены отвечают 404 (а не 401). Только для этого
  /// эндпоинта: на `telegram/link` и `invites/accept` 404 значит своё.
  static AuthFailure? profile(int status, String? message) =>
      status == 404 ? const AccountNotFoundFailure() : null;

  /// `/auth/telegram/link`.
  static AuthFailure? telegramLink(int status, String? message) {
    final text = message?.trim();

    return switch (status) {
      400 => const TelegramCodeInvalidFailure(),
      404 => const AccountNotFoundFailure(),
      409 => TelegramLinkConflictFailure(
        message: text == null || text.isEmpty ? null : text,
      ),
      _ => null,
    };
  }

  /// `/client/invites/accept`.
  static AuthFailure? inviteAccept(int status, String? message) =>
      switch (status) {
        404 => const InviteNotFoundFailure(),
        410 => const InviteExpiredFailure(),
        409 => InviteConflictParser.parse(message),
        422 => const InviteNotAllowedFailure(),
        403 => const AdminAccountFailure(),
        _ => null,
      };
}
