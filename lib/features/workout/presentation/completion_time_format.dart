import 'package:intl/intl.dart';

/// Дата и время отметки или ответа: «28 окт. 2026 г., 19:31». Сервер присылает UTC,
/// на экране — часовой пояс устройства; формат по языку приложения.
String formatCompletionTime(DateTime utc, String localeName) =>
    DateFormat.yMMMd(localeName).add_Hm().format(utc.toLocal());

/// Процент выполнения без лишних нулей: `66.7` → «66,7» / «66.7», `100` → «100».
String formatPercent(double percent, String localeName) =>
    NumberFormat('0.#', localeName).format(percent);
