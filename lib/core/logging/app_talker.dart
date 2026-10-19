import 'package:flutter/foundation.dart';
import 'package:mentorix_app/core/logging/console_logger_formatter.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Единственный экземпляр [Talker] приложения. Создаётся лениво и только в
/// debug-сборке: в release к нему никто не обращается (все вызовы проходят
/// проверку `DebugLog.enabled`), поэтому ни логов, ни истории там нет.
///
/// Пользуются им `AppLogger`, `DebugLog` и `MaskedTalkerDioLogger`; экран логов
/// (`TalkerScreen`) открывается долгим нажатием на заголовок профиля.
abstract final class AppTalker {
  static Talker? _instance;
  static bool _console = true;

  /// Сколько записей хранит экран логов. Старые вытесняются.
  static const maxHistoryItems = 1000;

  static Talker get instance {
    assert(
      DebugLog.enabled,
      'Talker используется только в debug-сборке: проверяйте DebugLog.enabled',
    );

    return _instance ??= Talker(
      logger: TalkerLogger(formatter: const ConsoleLoggerFormatter()),
      settings: TalkerSettings(
        useConsoleLogs: _console,
        maxHistoryItems: maxHistoryItems,
      ),
    );
  }

  /// Создан ли экземпляр. В release всегда `false`.
  @visibleForTesting
  static bool get isCreated => _instance != null;

  /// Только для тестов: чистый Talker. [console] — печатать ли в консоль
  /// (в тестах отключено, чтобы не засорять вывод).
  @visibleForTesting
  static void reset({bool console = false}) {
    _instance = null;
    _console = console;
  }
}
