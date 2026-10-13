import 'dart:convert';

/// Скрывает секреты в том, что попадает в логи: значение заменяется на `***`.
///
/// * Заголовки `Authorization`, `Cookie`, `Set-Cookie` — без учёта регистра.
/// * В телах (в том числе вложенных в списки и объекты, и в JSON-строках) —
///   поля из [_bodyKeys].
/// * `code` — секрет только в теле запроса `POST /auth/telegram/link` (код от
///   бота). В остальных ответах `code` — код ошибки, и он нужен для отладки.
abstract final class SecretMasker {
  static const mask = '***';

  static const _headerNames = {'authorization', 'cookie', 'set-cookie'};

  /// `token` — одноразовый токен приглашения тренера (`/client/invites/accept`).
  static const _bodyKeys = {
    'access_token',
    'refresh_token',
    'id_token',
    'apple_id_token',
    'apple_authorization_code',
    'token',
  };

  static bool isSecretHeader(String name) =>
      _headerNames.contains(name.toLowerCase());

  /// Копия заголовков со скрытыми значениями. Значения-списки (как в `Headers`
  /// ответа) остаются списками.
  static Map<String, dynamic> maskHeaders(Map<String, dynamic> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: isSecretHeader(entry.key)
            ? (entry.value is List ? [mask] : mask)
            : entry.value,
    };
  }

  /// Копия тела со скрытыми секретами. [maskCode] — скрывать и поле `code`
  /// (только для тела запроса привязки Telegram). Данные неизвестного вида
  /// возвращаются как есть.
  static Object? maskBody(Object? data, {bool maskCode = false}) {
    return switch (data) {
      Map() => {
        for (final entry in data.entries)
          entry.key: _isSecretKey(entry.key, maskCode)
              ? mask
              : maskBody(entry.value, maskCode: maskCode),
      },
      List() => [for (final item in data) maskBody(item, maskCode: maskCode)],
      String() => _maskJsonString(data, maskCode),
      _ => data,
    };
  }

  static bool _isSecretKey(Object? key, bool maskCode) {
    if (key is! String) return false;
    final lower = key.toLowerCase();
    return _bodyKeys.contains(lower) || (maskCode && lower == 'code');
  }

  /// Тело могло прийти строкой с JSON (сырой ответ). Не JSON — как есть.
  static String _maskJsonString(String text, bool maskCode) {
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return text;

    try {
      return jsonEncode(maskBody(jsonDecode(text), maskCode: maskCode));
    } on FormatException {
      return text;
    }
  }
}
