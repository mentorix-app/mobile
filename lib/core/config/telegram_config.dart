/// Telegram-бот, через который клиент привязывает Telegram и получает
/// приглашения тренера.
///
/// Имя бота приходит при сборке из `config/stage.json` (ключ `TELEGRAM_BOT_NAME`,
/// без `@`). Пока там плейсхолдер, кнопка «Открыть бота» неактивна.
abstract final class TelegramConfig {
  static const botNamePlaceholder = 'YOUR_TELEGRAM_BOT_NAME';

  static const botName = String.fromEnvironment(
    'TELEGRAM_BOT_NAME',
    defaultValue: botNamePlaceholder,
  );

  static const _host = 't.me';
  static const _linkStartParameter = 'link';

  static bool get isBotConfigured => isRealBotName(botName);

  static bool isRealBotName(String name) =>
      name.isNotEmpty && name != botNamePlaceholder;

  /// `https://t.me/<bot>?start=link` — шаг привязки Telegram.
  static Uri linkUri([String name = botName]) =>
      Uri.https(_host, name, {'start': _linkStartParameter});
}
