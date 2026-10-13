import 'package:dio/dio.dart';

/// Любая ошибка API — `{"code": "...", "message": "..."}`. Ветвиться нужно
/// **только по `code`**: он стабильный, а `message` бэкенд может менять, поэтому
/// его не разбирают и не показывают. Если особого кода нет, в `code` лежит имя
/// статуса (`bad_request`, `not_found`, `conflict`, …) — для таких случаев есть
/// разбор по статусу.
abstract final class ApiErrorCodes {
  // --- общие -----------------------------------------------------------------
  static const missingAuthorization = 'missing_authorization';
  static const invalidToken = 'invalid_token';
  static const invalidIdToken = 'invalid_id_token';
  static const invalidRefreshToken = 'invalid_refresh_token';
  static const rateLimited = 'rate_limited';
  static const userNotFound = 'user_not_found';
  static const providerNotConfigured = 'provider_not_configured';

  // --- привязка Telegram ------------------------------------------------------
  static const telegramLinkConflict = 'telegram_link_conflict';
  static const telegramAlreadyLinked = 'telegram_already_linked';
  static const invalidLinkCode = 'invalid_link_code';

  // --- приглашения -------------------------------------------------------------
  static const inviteConsumed = 'invite_consumed';
  static const clientLimitReached = 'client_limit_reached';
  static const inviteNotFound = 'invite_not_found';
  static const inviteExpired = 'invite_expired';
  static const selfInvite = 'self_invite';
  static const clientBlocked = 'client_blocked';
  static const adminCannotAccept = 'admin_cannot_accept';

  // --- удаление аккаунта (DELETE /auth/me) -------------------------------------
  static const appleAuthorizationRequired = 'apple_authorization_required';
  static const appleAccountMismatch = 'apple_account_mismatch';
  static const invalidAppleAuthorizationCode = 'invalid_apple_authorization_code';
  static const appleRevocationFailed = 'apple_revocation_failed';
  static const accountDeletionUnavailable = 'account_deletion_unavailable';

  /// `code` из тела ошибки или `null`, если тела или поля нет.
  static String? of(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map) {
      final code = data['code'];
      if (code is String && code.isNotEmpty) return code;
    }
    return null;
  }
}
