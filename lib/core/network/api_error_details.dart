/// Что сервер ответил на самом деле: для диагностики в debug-сборке.
///
/// Заполняется только в debug (маппер ошибок фичи), в release всегда `null`.
/// Решений по нему не принимается — только показ рядом с текстом ошибки.
class ApiErrorDetails {
  const ApiErrorDetails({this.status, this.code, this.transport});

  /// HTTP-статус; `null`, если ответа не было.
  final int? status;

  /// `code` из тела ответа.
  final String? code;

  /// Тип сбоя без ответа сервера (`connectionError`, `receiveTimeout`, …).
  final String? transport;

  /// `503 provider_not_configured`, `404`, `connectionError`.
  String get summary =>
      [?status, ?code, ?transport].map((part) => '$part').join(' ');
}
