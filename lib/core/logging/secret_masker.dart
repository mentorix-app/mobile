import 'dart:convert';

/// Скрывает секреты в том, что попадает в логи: значение заменяется на `***`.
///
/// * Заголовки `Authorization`, `Cookie`, `Set-Cookie` — без учёта регистра.
/// * В телах (в том числе вложенных в списки и объекты, и в JSON-строках) —
///   поля из [_bodyKeys].
/// * `code` — секрет только в теле запроса `POST /auth/telegram/link` (код от
///   бота). В остальных ответах `code` — код ошибки, и он нужен для отладки.
/// * Тексты тренировок — личные данные (могут касаться здоровья): `result_text`
///   (результат клиента, в запросе отметки и в статистике) и `text` ответа
///   тренера, но только внутри списка `comments`: `text` вне него не трогается.
abstract final class SecretMasker {
  static const mask = '***';

  static const _headerNames = {'authorization', 'cookie', 'set-cookie'};

  /// `token` — одноразовый токен приглашения тренера (`/client/invites/accept`);
  /// `nonce` — исходная строка защиты входа (`/auth/apple`, `/auth/google`);
  /// `result_text` — текст результата тренировки клиента.
  static const _bodyKeys = {
    'access_token',
    'refresh_token',
    'id_token',
    'apple_id_token',
    'apple_authorization_code',
    'token',
    'nonce',
    'result_text',
  };

  /// Список ответов тренера в статистике; `text` внутри его элементов скрывается.
  static const _commentsKey = 'comments';
  static const _commentTextKey = 'text';

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
              : _isComments(entry.key, entry.value)
              ? _maskComments(entry.value! as List, maskCode)
              : maskBody(entry.value, maskCode: maskCode),
      },
      List() => [for (final item in data) maskBody(item, maskCode: maskCode)],
      String() => _maskJsonString(data, maskCode),
      _ => data,
    };
  }

  static bool _isComments(Object? key, Object? value) =>
      key is String && key.toLowerCase() == _commentsKey && value is List;

  /// Элементы `comments`: `text` скрыт, остальные поля обрабатываются как обычно.
  static List<Object?> _maskComments(List<Object?> comments, bool maskCode) => [
    for (final item in comments)
      item is Map
          ? {
              for (final entry in item.entries)
                entry.key:
                    entry.key is String &&
                        (entry.key! as String).toLowerCase() == _commentTextKey
                    ? mask
                    : maskBody(entry.value, maskCode: maskCode),
            }
          : maskBody(item, maskCode: maskCode),
  ];

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
