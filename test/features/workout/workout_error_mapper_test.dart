import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/features/workout/data/mappers/workout_error_mapper.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/workout_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_en.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_ru.dart';

DioException _error(int status, {Object? data, DioExceptionType? type}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type ?? DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

DioException _coded(int status, String code, {String message = 'любой текст'}) =>
    _error(status, data: {'code': code, 'message': message});

void main() {
  tearDown(() => DebugLog.debugModeOverride = null);

  group('WorkoutErrorMapper — ветвление по code', () {
    // Статус намеренно «не тот»: разбор идёт по code, а не по статусу.
    const cases = <String, Type>{
      ApiErrorCodes.rateLimited: WorkoutTooManyRequestsFailure,
      ApiErrorCodes.missingAuthorization: WorkoutSessionExpiredFailure,
      ApiErrorCodes.invalidToken: WorkoutSessionExpiredFailure,
      ApiErrorCodes.invalidRefreshToken: WorkoutSessionExpiredFailure,
      ApiErrorCodes.clientNotLinked: WorkoutNotLinkedFailure,
      ApiErrorCodes.clientNotFound: WorkoutNotLinkedFailure,
      ApiErrorCodes.clientBlocked: WorkoutBlockedFailure,
      ApiErrorCodes.dayNotFound: WorkoutDayNotFoundFailure,
      ApiErrorCodes.workoutAlreadyCompleted: WorkoutAlreadyCompletedFailure,
      ApiErrorCodes.programChanged: WorkoutProgramChangedFailure,
      ApiErrorCodes.payloadTooLarge: WorkoutInvalidResultFailure,
    };

    cases.forEach((code, expected) {
      test('$code → $expected', () {
        expect(WorkoutErrorMapper.map(_coded(418, code)).runtimeType, expected);
      });
    });

    test('два вида 409 на отметке различаются только кодом', () {
      final changed = WorkoutErrorMapper.map(
        _coded(409, ApiErrorCodes.programChanged, message: 'conflict'),
      );
      final done = WorkoutErrorMapper.map(
        _coded(409, ApiErrorCodes.workoutAlreadyCompleted, message: 'conflict'),
      );

      expect(changed, isA<WorkoutProgramChangedFailure>());
      expect(done, isA<WorkoutAlreadyCompletedFailure>());
    });

    test('«нет связи» с тренером: 403 на программе и 404 на статистике', () {
      expect(
        WorkoutErrorMapper.map(_coded(403, ApiErrorCodes.clientNotLinked)),
        isA<WorkoutNotLinkedFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_coded(404, ApiErrorCodes.clientNotFound)),
        isA<WorkoutNotLinkedFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_coded(422, ApiErrorCodes.clientBlocked)),
        isA<WorkoutBlockedFailure>(),
      );
    });

    test('message не влияет на результат: ни текст, ни его отсутствие', () {
      final other = WorkoutErrorMapper.map(
        _coded(409, ApiErrorCodes.programChanged, message: 'совсем другой'),
      );
      final noCode = WorkoutErrorMapper.map(
        _error(409, data: {'message': 'program changed'}),
      );

      expect(other, isA<WorkoutProgramChangedFailure>());
      expect(noCode, isA<WorkoutUnknownFailure>());
    });

    test('code приоритетнее статуса', () {
      final failure = WorkoutErrorMapper.map(
        _coded(503, ApiErrorCodes.dayNotFound),
      );

      expect(failure, isA<WorkoutDayNotFoundFailure>());
    });
  });

  group('WorkoutErrorMapper — неизвестный code → по статусу', () {
    test('имена статусов вместо кодов: bad_request / not_found / conflict', () {
      expect(
        WorkoutErrorMapper.map(_coded(400, 'bad_request')),
        isA<WorkoutInvalidRequestFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_coded(404, 'not_found')),
        isA<WorkoutUnknownFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_coded(409, 'conflict')),
        isA<WorkoutUnknownFailure>(),
      );
    });

    test('новый, ещё не известный клиенту code', () {
      expect(
        WorkoutErrorMapper.map(_coded(429, 'some_future_code')),
        isA<WorkoutTooManyRequestsFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_coded(503, 'some_future_code')),
        isA<WorkoutServerUnavailableFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_coded(401, 'some_future_code')),
        isA<WorkoutSessionExpiredFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_coded(422, 'some_future_code')),
        isA<WorkoutUnknownFailure>(),
      );
    });

    test('тела нет, тело не объект или code не строка', () {
      expect(
        WorkoutErrorMapper.map(_error(400)),
        isA<WorkoutInvalidRequestFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_error(500, data: 'Internal Server Error')),
        isA<WorkoutUnknownFailure>(),
      );
      expect(
        WorkoutErrorMapper.map(_error(400, data: {'code': 42})),
        isA<WorkoutInvalidRequestFailure>(),
      );
    });
  });

  group('WorkoutErrorMapper.completion — отметка дня', () {
    WorkoutFailure map(DioException e) =>
        WorkoutErrorMapper.map(e, endpoint: WorkoutErrorMapper.completion);

    test('400 (пустой текст, слишком длинный, не хватает полей) и 413', () {
      expect(map(_coded(400, 'bad_request')), isA<WorkoutInvalidResultFailure>());
      expect(map(_error(400)), isA<WorkoutInvalidResultFailure>());
      expect(
        map(_coded(413, ApiErrorCodes.payloadTooLarge)),
        isA<WorkoutInvalidResultFailure>(),
      );
      expect(map(_error(413)), isA<WorkoutInvalidResultFailure>());
    });

    test('404, 409, 403, 422 разбираются по code, как везде', () {
      expect(
        map(_coded(404, ApiErrorCodes.dayNotFound)),
        isA<WorkoutDayNotFoundFailure>(),
      );
      expect(
        map(_coded(409, ApiErrorCodes.workoutAlreadyCompleted)),
        isA<WorkoutAlreadyCompletedFailure>(),
      );
      expect(
        map(_coded(409, ApiErrorCodes.programChanged)),
        isA<WorkoutProgramChangedFailure>(),
      );
      expect(
        map(_coded(403, ApiErrorCodes.clientNotLinked)),
        isA<WorkoutNotLinkedFailure>(),
      );
      expect(
        map(_coded(422, ApiErrorCodes.clientBlocked)),
        isA<WorkoutBlockedFailure>(),
      );
    });

    test('на программе тот же 400 — «неверный запрос», а не результат', () {
      expect(
        WorkoutErrorMapper.map(_coded(400, 'bad_request')),
        isA<WorkoutInvalidRequestFailure>(),
      );
    });

    test('429 и 503 не перехватываются', () {
      expect(map(_error(429)), isA<WorkoutTooManyRequestsFailure>());
      expect(map(_error(503)), isA<WorkoutServerUnavailableFailure>());
    });
  });

  group('WorkoutErrorMapper — без ответа сервера', () {
    test('таймаут и обрыв связи — сеть', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final e = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: type,
        );
        expect(WorkoutErrorMapper.map(e), isA<WorkoutNetworkFailure>());
      }
    });

    test('сессия завершена перехватчиком — SessionExpired', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const SessionExpiredException(),
      );

      expect(WorkoutErrorMapper.map(e), isA<WorkoutSessionExpiredFailure>());
    });

    test('ни ответа, ни известного типа — Unknown', () {
      final e = DioException(requestOptions: RequestOptions(path: '/x'));

      expect(WorkoutErrorMapper.map(e), isA<WorkoutUnknownFailure>());
    });
  });

  group('WorkoutFailureMessage', () {
    final ru = AppLocalizationsRu();
    final en = AppLocalizationsEn();

    // Исчерпывающий список: новый подтип без строки сюда не попадёт, а
    // `_text` в расширении без него не скомпилируется.
    const failures = <WorkoutFailure>[
      WorkoutNetworkFailure(),
      WorkoutServerUnavailableFailure(),
      WorkoutTooManyRequestsFailure(),
      WorkoutSessionExpiredFailure(),
      WorkoutInvalidRequestFailure(),
      WorkoutUnknownFailure(),
      WorkoutNotLinkedFailure(),
      WorkoutBlockedFailure(),
      WorkoutDayNotFoundFailure(),
      WorkoutAlreadyCompletedFailure(),
      WorkoutProgramChangedFailure(),
      WorkoutInvalidResultFailure(),
    ];

    test('у каждой ошибки непустой русский и английский текст, все разные', () {
      final russian = {for (final f in failures) f.message(ru, debug: false)};
      final english = {for (final f in failures) f.message(en, debug: false)};

      expect(russian, hasLength(failures.length));
      expect(english, hasLength(failures.length));
      expect(russian, isNot(contains('')));
      expect(english, isNot(contains('')));
    });

    test('тексты по смыслу', () {
      expect(
        const WorkoutProgramChangedFailure().message(ru, debug: false),
        'Тренер обновил программу. Проверьте день и отправьте результат снова.',
      );
      expect(
        const WorkoutAlreadyCompletedFailure().message(en, debug: false),
        'This day is already marked as done.',
      );
    });

    test('debug: к тексту добавляются статус и code; release — без них', () {
      final failure = WorkoutErrorMapper.map(
        _coded(404, ApiErrorCodes.dayNotFound),
      );

      expect(
        failure.message(ru, debug: true),
        'Этого дня больше нет в программе. (404 day_not_found)',
      );
      expect(failure.message(ru, debug: false), 'Этого дня больше нет в программе.');
    });

    test('в release details не создаются вовсе', () {
      DebugLog.debugModeOverride = false;

      final failure = WorkoutErrorMapper.map(
        _coded(409, ApiErrorCodes.programChanged),
      );

      expect(failure.details, isNull);
    });

    test('без ответа сервера в debug — тип сбоя', () {
      final failure = WorkoutErrorMapper.map(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(failure.details?.summary, 'connectionError');
    });
  });
}
