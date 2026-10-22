import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Локализованный текст ошибки тренировок. Сырой текст бэкенда сюда не попадает.
///
/// Список исчерпывающий (без `_`): новый подтип [WorkoutFailure] не
/// компилируется, пока для него нет текста.
extension WorkoutFailureMessage on WorkoutFailure {
  /// [debug] по умолчанию — debug-сборка: к тексту добавляется ответ сервера,
  /// «Не удалось … (404 day_not_found)». В release остаётся только текст.
  String message(AppLocalizations l10n, {bool? debug}) {
    final isDebug = debug ?? DebugLog.enabled;
    final info = isDebug ? details?.summary : null;
    final text = _text(l10n);

    return info == null || info.isEmpty ? text : '$text ($info)';
  }

  String _text(AppLocalizations l10n) => switch (this) {
    WorkoutNetworkFailure() => l10n.errorNetwork,
    WorkoutServerUnavailableFailure() => l10n.errorServerUnavailable,
    WorkoutTooManyRequestsFailure() => l10n.errorTooManyRequests,
    WorkoutSessionExpiredFailure() => l10n.errorSessionExpired,
    WorkoutInvalidRequestFailure() => l10n.errorInvalidRequest,
    WorkoutUnknownFailure() => l10n.errorUnknown,
    WorkoutNotLinkedFailure() => l10n.errorWorkoutNotLinked,
    WorkoutBlockedFailure() => l10n.errorWorkoutBlocked,
    WorkoutDayNotFoundFailure() => l10n.errorWorkoutDayNotFound,
    WorkoutAlreadyCompletedFailure() => l10n.errorWorkoutAlreadyCompleted,
    WorkoutProgramChangedFailure() => l10n.errorWorkoutProgramChanged,
    WorkoutInvalidResultFailure() => l10n.errorWorkoutInvalidResult,
  };
}
