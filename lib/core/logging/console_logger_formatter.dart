import 'package:talker_flutter/talker_flutter.dart';

/// Формат консоли `flutter run`: записи HTTP без блока `Headers:`.
///
/// Заголовки остаются в самой записи, поэтому экран логов (`TalkerScreen`)
/// их показывает: он берёт текст записи, а не вывод этого форматтера. Блок
/// всегда стоит последним (после `Data:`), а в JSON-теле перевод строки
/// экранирован, так что ложно сработать на теле нечему.
class ConsoleLoggerFormatter implements LoggerFormatter {
  const ConsoleLoggerFormatter([
    this._inner = const ExtendedLoggerFormatter(),
  ]);

  static const _headersMarker = '\nHeaders: ';

  final LoggerFormatter _inner;

  @override
  String fmt(LogDetails details, TalkerLoggerSettings settings) {
    final message = details.message;
    if (message is! String || !message.startsWith('[http-')) {
      return _inner.fmt(details, settings);
    }

    final start = message.lastIndexOf(_headersMarker);
    if (start < 0) return _inner.fmt(details, settings);

    return _inner.fmt(
      LogDetails(
        message: message.substring(0, start),
        level: details.level,
        pen: details.pen,
      ),
      settings,
    );
  }
}
