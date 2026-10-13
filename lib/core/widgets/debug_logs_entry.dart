import 'package:flutter/material.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Вход на экран логов (`TalkerScreen`) долгим нажатием на [child].
///
/// Только в debug-сборке: в release возвращает [child] как есть — ни обработчика
/// жеста, ни экрана.
class DebugLogsEntry extends StatelessWidget {
  const DebugLogsEntry({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!DebugLog.enabled) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TalkerScreen(talker: AppTalker.instance),
        ),
      ),
      child: child,
    );
  }
}
