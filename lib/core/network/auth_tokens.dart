/// Ответ `TokenResponse` из `docs/auth_api.md` — результат входа, refresh
/// и привязки Telegram.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.expiresAt,
  });

  /// Бросает [FormatException], если в ответе нет токенов или `user_id`:
  /// сохранять половину сессии нельзя.
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final userId = json['user_id'];
    final expiresAt = json['expires_at'];

    if (access is! String || access.isEmpty) {
      throw const FormatException('access_token is missing');
    }
    if (refresh is! String || refresh.isEmpty) {
      throw const FormatException('refresh_token is missing');
    }
    // user_id — UUID строкой (контракт); число или null — не тот ответ.
    if (userId is! String || userId.isEmpty) {
      throw const FormatException('user_id is missing');
    }

    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
      expiresAt: parseExpiresAt(expiresAt),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String userId;

  /// `null`, если значение не разобралось: тогда токен обновляется только по 401.
  final DateTime? expiresAt;

  /// `expires_at` — строка ISO 8601 в UTC, например `2026-10-12T06:15:00Z`
  /// (ответ бэкенда, `docs/backend_answers.md`). Всё остальное — `null`.
  static DateTime? parseExpiresAt(Object? value) {
    // `DateTime.tryParse('1893456000')` читает число как год, поэтому форма
    // «дата T время» проверяется отдельно.
    if (value is! String || !_isoDateTime.hasMatch(value)) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  static final _isoDateTime = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}');
}
