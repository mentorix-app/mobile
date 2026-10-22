import 'package:dio/dio.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/core/network/api_error_details.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

/// Разбор, специфичный для эндпоинта; `null` — «не знаю», решает общий разбор.
typedef WorkoutEndpointMapper = WorkoutFailure? Function(int status, String? code);

/// Ошибка API → доменный [WorkoutFailure].
///
/// Ветвление — **только по `code`** из тела ответа (`{"code","message"}`):
/// `message` бэкенд вправе менять, он не разбирается и пользователю не
/// показывается. Неизвестный `code` (в том числе имена статусов `bad_request`,
/// `not_found`, `conflict`) разбирается по HTTP-статусу. На 429 ничего не
/// повторяется.
abstract final class WorkoutErrorMapper {
  static const _networkTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  /// В debug-сборке к ошибке прикладывается статус и `code` ответа
  /// ([ApiErrorDetails]); в release `details` не создаётся вовсе.
  static WorkoutFailure map(DioException e, {WorkoutEndpointMapper? endpoint}) {
    final failure = _resolve(e, endpoint);
    if (!DebugLog.enabled) return failure;

    final response = e.response;
    return failure.withDetails(
      ApiErrorDetails(
        status: response?.statusCode,
        code: ApiErrorCodes.of(response),
        transport: response == null ? e.type.name : null,
      ),
    );
  }

  static WorkoutFailure _resolve(DioException e, WorkoutEndpointMapper? endpoint) {
    if (e.error is SessionExpiredException) {
      return const WorkoutSessionExpiredFailure();
    }

    if (_networkTypes.contains(e.type)) return const WorkoutNetworkFailure();

    final status = e.response?.statusCode;
    if (status == null) return const WorkoutUnknownFailure();

    final code = ApiErrorCodes.of(e.response);

    final specific = endpoint?.call(status, code);
    if (specific != null) return specific;

    final byCode = code == null ? null : fromCode(code);
    if (byCode != null) return byCode;

    return _fromStatus(status);
  }

  /// Известный `code` → ошибка; неизвестный → `null`.
  static WorkoutFailure? fromCode(String code) => switch (code) {
    ApiErrorCodes.rateLimited => const WorkoutTooManyRequestsFailure(),
    ApiErrorCodes.missingAuthorization ||
    ApiErrorCodes.invalidToken ||
    ApiErrorCodes.invalidRefreshToken => const WorkoutSessionExpiredFailure(),
    ApiErrorCodes.clientNotLinked ||
    ApiErrorCodes.clientNotFound => const WorkoutNotLinkedFailure(),
    ApiErrorCodes.clientBlocked => const WorkoutBlockedFailure(),
    ApiErrorCodes.dayNotFound => const WorkoutDayNotFoundFailure(),
    ApiErrorCodes.workoutAlreadyCompleted =>
      const WorkoutAlreadyCompletedFailure(),
    ApiErrorCodes.programChanged => const WorkoutProgramChangedFailure(),
    ApiErrorCodes.payloadTooLarge => const WorkoutInvalidResultFailure(),
    _ => null,
  };

  /// Общий текст по статусу, когда `code` неизвестен.
  static WorkoutFailure _fromStatus(int status) => switch (status) {
    429 => const WorkoutTooManyRequestsFailure(),
    503 => const WorkoutServerUnavailableFailure(),
    400 => const WorkoutInvalidRequestFailure(),
    401 => const WorkoutSessionExpiredFailure(),
    _ => const WorkoutUnknownFailure(),
  };

  /// `POST …/completions`: 400 (пустой текст, длиннее 1000 символов, запрещённые
  /// символы, нет полей) и 413 (тело больше 16 КБ) — проблема с результатом, а не
  /// «неверный запрос». Известные `code` (404, 409, 403, 422) эта ветка не
  /// перехватывает.
  static WorkoutFailure? completion(int status, String? code) =>
      status == 400 || status == 413
      ? const WorkoutInvalidResultFailure()
      : null;
}
