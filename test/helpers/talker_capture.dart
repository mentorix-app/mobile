import 'package:mentorix_app/core/logging/app_talker.dart';

/// Чистый Talker перед тестом (без вывода в консоль).
void resetTalker() => AppTalker.reset();

/// Тексты записей, как их передали (`[mentorix.apple] …`). Для записей Dio это
/// только адрес — полный текст в [loggedText].
List<String> loggedMessages() => AppTalker.isCreated
    ? [for (final data in AppTalker.instance.history) data.message ?? '']
    : const [];

/// Полный текст записей, каким он виден на экране логов: заголовки, тела,
/// статус, время.
List<String> loggedText() => AppTalker.isCreated
    ? [
        for (final data in AppTalker.instance.history)
          data.generateTextMessage(),
      ]
    : const [];
