import 'package:mentorix_app/core/network/api_error_details.dart';

/// Доменные ошибки тренировок: список тренеров, программа, отметка дня и
/// статистика. Текста здесь нет: пользователю сообщение подставляет слой
/// представления по типу ошибки (`workout_failure_message.dart`).
///
/// Подтипы выбираются по `code` из тела ответа, а не по тексту `message`
/// (`WorkoutErrorMapper`).
sealed class WorkoutFailure implements Exception {
  const WorkoutFailure({this.details});

  /// Ответ сервера для debug-показа; в release `null`.
  final ApiErrorDetails? details;
}

// --- общие -----------------------------------------------------------------

/// Нет связи, таймаут соединения или ответа.
final class WorkoutNetworkFailure extends WorkoutFailure {
  const WorkoutNetworkFailure({super.details});
}

/// 503: сервис временно недоступен.
final class WorkoutServerUnavailableFailure extends WorkoutFailure {
  const WorkoutServerUnavailableFailure({super.details});
}

/// 429. Автоматически ничего не повторяется.
final class WorkoutTooManyRequestsFailure extends WorkoutFailure {
  const WorkoutTooManyRequestsFailure({super.details});
}

/// Токены не помогли: нужен вход. Сессию завершает `SessionCubit`.
final class WorkoutSessionExpiredFailure extends WorkoutFailure {
  const WorkoutSessionExpiredFailure({super.details});
}

/// 400 без более точного смысла (`bad_request` и неизвестный `code`).
final class WorkoutInvalidRequestFailure extends WorkoutFailure {
  const WorkoutInvalidRequestFailure({super.details});
}

final class WorkoutUnknownFailure extends WorkoutFailure {
  const WorkoutUnknownFailure({super.details});
}

// --- связь с тренером -------------------------------------------------------

/// 403 `client_not_linked` (программа, отметка) или 404 `client_not_found`
/// (статистика): связи с этим тренером нет.
final class WorkoutNotLinkedFailure extends WorkoutFailure {
  const WorkoutNotLinkedFailure({super.details});
}

/// 422 `client_blocked`: тренер заблокировал клиента.
final class WorkoutBlockedFailure extends WorkoutFailure {
  const WorkoutBlockedFailure({super.details});
}

// --- отметка дня -------------------------------------------------------------

/// 404 `day_not_found`: такого дня нет в программе клиента или в нём нет
/// упражнений (день отдыха).
final class WorkoutDayNotFoundFailure extends WorkoutFailure {
  const WorkoutDayNotFoundFailure({super.details});
}

/// 409 `workout_already_completed`: день уже отмечен в этом цикле (в том числе в
/// Telegram-боте или прошлым запросом, ответ на который потерялся).
final class WorkoutAlreadyCompletedFailure extends WorkoutFailure {
  const WorkoutAlreadyCompletedFailure({super.details});
}

/// 409 `program_changed`: назначение, версия или цикл изменились после того, как
/// клиент загрузил программу (или назначения больше нет). Программу нужно
/// перезагрузить; ничего не записано.
final class WorkoutProgramChangedFailure extends WorkoutFailure {
  const WorkoutProgramChangedFailure({super.details});
}

/// 400 или 413 на отметке: текст результата пуст, длиннее 1000 символов,
/// с запрещёнными символами или тело слишком большое.
final class WorkoutInvalidResultFailure extends WorkoutFailure {
  const WorkoutInvalidResultFailure({super.details});
}

/// Копия ошибки с [details]. Список исчерпывающий: новый подтип не
/// компилируется, пока не решено, как его копировать.
extension WorkoutFailureDetails on WorkoutFailure {
  WorkoutFailure withDetails(ApiErrorDetails? details) {
    if (details == null) return this;

    return switch (this) {
      WorkoutNetworkFailure() => WorkoutNetworkFailure(details: details),
      WorkoutServerUnavailableFailure() => WorkoutServerUnavailableFailure(
        details: details,
      ),
      WorkoutTooManyRequestsFailure() => WorkoutTooManyRequestsFailure(
        details: details,
      ),
      WorkoutSessionExpiredFailure() => WorkoutSessionExpiredFailure(
        details: details,
      ),
      WorkoutInvalidRequestFailure() => WorkoutInvalidRequestFailure(
        details: details,
      ),
      WorkoutUnknownFailure() => WorkoutUnknownFailure(details: details),
      WorkoutNotLinkedFailure() => WorkoutNotLinkedFailure(details: details),
      WorkoutBlockedFailure() => WorkoutBlockedFailure(details: details),
      WorkoutDayNotFoundFailure() => WorkoutDayNotFoundFailure(
        details: details,
      ),
      WorkoutAlreadyCompletedFailure() => WorkoutAlreadyCompletedFailure(
        details: details,
      ),
      WorkoutProgramChangedFailure() => WorkoutProgramChangedFailure(
        details: details,
      ),
      WorkoutInvalidResultFailure() => WorkoutInvalidResultFailure(
        details: details,
      ),
    };
  }
}

/// Повтор запроса имеет смысл. Для связи, которой больше нет, и блокировки
/// тренером повтор ничего не изменит: экран показывает сообщение без
/// «Повторить». Список исчерпывающий: новый подтип не компилируется, пока не
/// решено, повторяем ли мы его.
extension WorkoutFailureRetry on WorkoutFailure {
  bool get canRetry => switch (this) {
    WorkoutNotLinkedFailure() || WorkoutBlockedFailure() => false,
    WorkoutNetworkFailure() ||
    WorkoutServerUnavailableFailure() ||
    WorkoutTooManyRequestsFailure() ||
    WorkoutSessionExpiredFailure() ||
    WorkoutInvalidRequestFailure() ||
    WorkoutUnknownFailure() ||
    WorkoutDayNotFoundFailure() ||
    WorkoutAlreadyCompletedFailure() ||
    WorkoutProgramChangedFailure() ||
    WorkoutInvalidResultFailure() => true,
  };
}
