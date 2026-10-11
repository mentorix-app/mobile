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

    if (access is! String || access.isEmpty) {
      throw const FormatException('access_token is missing');
    }
    if (refresh is! String || refresh.isEmpty) {
      throw const FormatException('refresh_token is missing');
    }
    if (userId == null || userId.toString().isEmpty) {
      throw const FormatException('user_id is missing');
    }

    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      userId: userId.toString(),
      expiresAt: parseExpiresAt(json['expires_at']),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String userId;

  /// `null`, если формат `expires_at` не распознан: тогда токен обновляется
  /// только по 401.
  final DateTime? expiresAt;

  /// Формат `expires_at` в `auth_api.md` не описан, поэтому разбор терпимый:
  /// ISO-8601, unix-секунды или unix-миллисекунды (число или строка).
  static DateTime? parseExpiresAt(Object? value) {
    if (value is num) return _fromEpoch(value.toInt());
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null) return _fromEpoch(asInt);
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  static DateTime _fromEpoch(int value) {
    // 1e12 мс — это 2001 год, 1e12 с — 33658 год: граница однозначна.
    final millis = value.abs() >= 1000000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}
