import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/features/workout/data/datasources/workout_remote_datasource.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_target.dart';
import 'package:mentorix_app/features/workout/domain/entities/workout_completion.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/talker_capture.dart';

void main() {
  late FakeHttpAdapter adapter;
  late WorkoutRemoteDataSource remote;

  void setUpRemote(FakeResponder responder) {
    adapter = FakeHttpAdapter(responder);
    remote = WorkoutRemoteDataSource(
      apiDio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );
  }

  group('trainers', () {
    test('образец docs/samples/client_trainers.json', () async {
      final sample =
          jsonDecode(File('docs/samples/client_trainers.json').readAsStringSync())
              as Map<String, dynamic>;
      setUpRemote((_) async => jsonBody(sample));

      final trainers = await remote.trainers();

      expect(trainers, hasLength(1));
      expect(trainers.single.trainerId, '909027e1-fc56-4969-8fc5-943a949f0441');
      expect(trainers.single.trainerDisplayName, 'Test free trainer');
      expect(trainers.single.linkedAt, DateTime.utc(2026, 10, 20, 15, 23, 22, 347, 897));
    });

    test('идёт на путь из ApiEndpoints методом GET', () async {
      setUpRemote((_) async => jsonBody({'items': []}));

      await remote.trainers();

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, ApiEndpoints.clientTrainers);
      expect(adapter.requests.single.method, 'GET');
    });

    test('пустой items — пустой список, а не ошибка', () async {
      setUpRemote((_) async => jsonBody({'items': []}));

      expect(await remote.trainers(), isEmpty);
    });

    test('порядок сервера сохраняется, пустое и отсутствующее имя допустимы', () async {
      setUpRemote(
        (_) async => jsonBody({
          'items': [
            {'trainer_id': 'b', 'trainer_display_name': ''},
            {'trainer_id': 'a'},
            {'trainer_id': 'c', 'trainer_display_name': null, 'new_field': 1},
          ],
        }),
      );

      final trainers = await remote.trainers();

      expect(trainers.map((t) => t.trainerId), ['b', 'a', 'c']);
      expect(trainers.map((t) => t.trainerDisplayName), ['', '', '']);
    });

    test('битые элементы пропускаются, остальные остаются', () async {
      setUpRemote(
        (_) async => jsonBody({
          'items': [
            'строка',
            {'trainer_display_name': 'без id'},
            {'trainer_id': '', 'trainer_display_name': 'пустой id'},
            {'trainer_id': 'ok', 'trainer_display_name': 'Тренер'},
            null,
          ],
        }),
      );

      final trainers = await remote.trainers();

      expect(trainers.map((t) => t.trainerId), ['ok']);
      expect(
        loggedMessages(),
        containsAll([
          contains('skipped items: 2 item(s) are not objects'),
          contains('skipped trainers: item without trainer_id'),
        ]),
      );
      // Содержимое пропущенных элементов в лог не попадает.
      expect(loggedMessages().join(), isNot(contains('без id')));
    });

    test('нет items или он не список — Unknown, а не «тренера нет»', () async {
      for (final body in <Object>[
        <String, Object?>{},
        {'items': null},
        {'items': {'a': 1}},
        [1, 2],
        'text',
      ]) {
        setUpRemote((_) async => jsonBody(body));

        await expectLater(
          remote.trainers(),
          throwsA(isA<WorkoutUnknownFailure>()),
          reason: '$body',
        );
      }
    });

    test('ошибки разбираются по code', () async {
      final cases = <int, Object>{
        401: {'code': ApiErrorCodes.invalidToken},
        403: {'code': ApiErrorCodes.clientNotLinked},
        429: {'code': ApiErrorCodes.rateLimited},
        503: {'code': 'service_unavailable'},
        500: {'code': 'internal'},
      };
      final expected = <int, Type>{
        401: WorkoutSessionExpiredFailure,
        403: WorkoutNotLinkedFailure,
        429: WorkoutTooManyRequestsFailure,
        503: WorkoutServerUnavailableFailure,
        500: WorkoutUnknownFailure,
      };

      for (final entry in cases.entries) {
        setUpRemote((_) async => jsonBody(entry.value, status: entry.key));

        await expectLater(
          remote.trainers(),
          throwsA(predicate((e) => e.runtimeType == expected[entry.key])),
          reason: '${entry.key}',
        );
      }
    });

    test('обрыв связи — Network', () async {
      setUpRemote(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        remote.trainers(),
        throwsA(isA<WorkoutNetworkFailure>()),
      );
    });
  });

  group('program', () {
    const trainerId = '404dd1be-d973-4b97-8294-28a9e1fe38a9';

    test('образец docs/samples/client_program.json', () async {
      final sample =
          jsonDecode(File('docs/samples/client_program.json').readAsStringSync())
              as Map<String, dynamic>;
      setUpRemote((_) async => jsonBody(sample));

      final program = await remote.program(trainerId);

      expect(program.trainerId, trainerId, reason: 'идентификатор — из пути запроса');
      expect(program.hasProgram, isTrue);
      expect(program.weeks, hasLength(2));
    });

    test('идёт на путь из ApiEndpoints методом GET', () async {
      setUpRemote((_) async => jsonBody({'assignment': null, 'program': null, 'completed_days': []}));

      final program = await remote.program(trainerId);

      expect(adapter.requests.single.path, ApiEndpoints.clientTrainerProgram(trainerId));
      expect(adapter.requests.single.method, 'GET');
      expect(program.hasProgram, isFalse);
    });

    test('ошибки разбираются по code', () async {
      final cases = <int, ({Object body, Type failure})>{
        403: (body: {'code': ApiErrorCodes.clientNotLinked}, failure: WorkoutNotLinkedFailure),
        422: (body: {'code': ApiErrorCodes.clientBlocked}, failure: WorkoutBlockedFailure),
        400: (body: {'code': 'bad_request'}, failure: WorkoutInvalidRequestFailure),
        401: (body: {'code': ApiErrorCodes.invalidToken}, failure: WorkoutSessionExpiredFailure),
        429: (body: {'code': ApiErrorCodes.rateLimited}, failure: WorkoutTooManyRequestsFailure),
        503: (body: {'code': 'x'}, failure: WorkoutServerUnavailableFailure),
        500: (body: {'code': 'internal'}, failure: WorkoutUnknownFailure),
      };

      for (final entry in cases.entries) {
        setUpRemote((_) async => jsonBody(entry.value.body, status: entry.key));

        await expectLater(
          remote.program(trainerId),
          throwsA(predicate((e) => e.runtimeType == entry.value.failure)),
          reason: '${entry.key}',
        );
      }
    });

    test('тело не объект — Unknown', () async {
      for (final body in <Object>[[1], 'text', 5]) {
        setUpRemote((_) async => jsonBody(body));

        await expectLater(
          remote.program(trainerId),
          throwsA(isA<WorkoutUnknownFailure>()),
          reason: '$body',
        );
      }
    });

    test('обрыв связи — Network', () async {
      setUpRemote(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(remote.program(trainerId), throwsA(isA<WorkoutNetworkFailure>()));
    });
  });

  group('completeDay', () {
    const trainerId = '404dd1be-d973-4b97-8294-28a9e1fe38a9';
    const target = CompletionTarget(
      assignmentId: 'assignment-1',
      programVersionId: 'version-1',
      completionCycleId: 'cycle-1',
      dayKey: 'day-key-1',
    );

    Future<WorkoutCompletion> send([String text = 'Сделал 5x5']) => remote.completeDay(
      trainerId: trainerId,
      target: target,
      resultText: text,
    );

    test('POST на путь из ApiEndpoints с телом из слепка и текста', () async {
      setUpRemote(
        (_) async => jsonBody({
          'id': 'c-1',
          'day_key': 'day-key-1',
          'week_number': 1,
          'day_number': 4,
          'completed_at': '2026-10-28T10:00:00Z',
          'result_text': 'Сделал 5x5',
        }, status: 201),
      );

      final result = await send();

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, ApiEndpoints.clientTrainerCompletions(trainerId));
      expect(request.data, {
        'program_assignment_id': 'assignment-1',
        'program_version_id': 'version-1',
        'completion_cycle_id': 'cycle-1',
        'day_key': 'day-key-1',
        'result_text': 'Сделал 5x5',
      });
      expect(request.headers[Headers.contentTypeHeader], contains('application/json'));
      expect(result.id, 'c-1');
      expect(result.dayKey, 'day-key-1');
      expect(result.weekNumber, 1);
      expect(result.dayNumber, 4);
      expect(result.completedAt, DateTime.utc(2026, 10, 28, 10));
      expect(result.resultText, 'Сделал 5x5');
    });

    test('отметка записана, а тело ответа неожиданное — это успех', () async {
      for (final body in <Object>[<String, Object?>{}, [1, 2], 'ok', {'id': null}]) {
        setUpRemote((_) async => jsonBody(body, status: 201));

        final result = await send();

        expect(result.dayKey, 'day-key-1', reason: '$body');
      }
    });

    test('ответ без тела (204-подобный) — тоже успех', () async {
      setUpRemote((_) async => ResponseBody.fromString('', 201));

      final result = await send();

      expect(result.dayKey, 'day-key-1');
    });

    test('управляющие символы в ответе убираются', () async {
      setUpRemote(
        (_) async => jsonBody({'id': 'x', 'result_text': 'a\u0000b'}, status: 201),
      );

      expect((await send()).resultText, 'ab');
    });

    test('ошибки разбираются по code', () async {
      final cases = <String, ({int status, Object body, Type failure})>{
        '409 program_changed': (
          status: 409,
          body: {'code': ApiErrorCodes.programChanged},
          failure: WorkoutProgramChangedFailure,
        ),
        '409 workout_already_completed': (
          status: 409,
          body: {'code': ApiErrorCodes.workoutAlreadyCompleted},
          failure: WorkoutAlreadyCompletedFailure,
        ),
        '404 day_not_found': (
          status: 404,
          body: {'code': ApiErrorCodes.dayNotFound},
          failure: WorkoutDayNotFoundFailure,
        ),
        '400 bad_request (пустой текст, длиннее 1000)': (
          status: 400,
          body: {'code': 'bad_request'},
          failure: WorkoutInvalidResultFailure,
        ),
        '413 payload_too_large': (
          status: 413,
          body: {'code': ApiErrorCodes.payloadTooLarge},
          failure: WorkoutInvalidResultFailure,
        ),
        '403 client_not_linked': (
          status: 403,
          body: {'code': ApiErrorCodes.clientNotLinked},
          failure: WorkoutNotLinkedFailure,
        ),
        '422 client_blocked': (
          status: 422,
          body: {'code': ApiErrorCodes.clientBlocked},
          failure: WorkoutBlockedFailure,
        ),
        '429': (
          status: 429,
          body: {'code': ApiErrorCodes.rateLimited},
          failure: WorkoutTooManyRequestsFailure,
        ),
        '503': (
          status: 503,
          body: {'code': 'x'},
          failure: WorkoutServerUnavailableFailure,
        ),
        '500': (status: 500, body: {'code': 'x'}, failure: WorkoutUnknownFailure),
      };

      for (final entry in cases.entries) {
        setUpRemote((_) async => jsonBody(entry.value.body, status: entry.value.status));

        await expectLater(
          send(),
          throwsA(predicate((e) => e.runtimeType == entry.value.failure)),
          reason: entry.key,
        );
      }
    });

    test('обрыв связи — Network (отметка могла дойти: повтор даст 409)', () async {
      setUpRemote(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(send(), throwsA(isA<WorkoutNetworkFailure>()));
    });

    test('результат тренировки в журнале запросов скрыт', () async {
      setUpRemote((_) async => jsonBody({'id': 'x'}, status: 201));

      await send('Колено болело');

      // Настоящий запрос ушёл с текстом, а в журнал он попадает только маской.
      expect(adapter.requests.single.data['result_text'], 'Колено болело');
    });
  });

  group('analytics', () {
    const trainerId = '404dd1be-d973-4b97-8294-28a9e1fe38a9';

    test('образцы docs/samples/client_analytics*.json', () async {
      for (final name in ['client_analytics.json', 'client_analytics_empty.json']) {
        final sample = jsonDecode(File('docs/samples/$name').readAsStringSync());
        setUpRemote((_) async => jsonBody(sample as Object));

        final analytics = await remote.analytics(trainerId);

        expect(analytics.currentAssignment, isNotNull, reason: name);
      }
    });

    test('GET на путь из ApiEndpoints, не на подписанную ссылку бота', () async {
      setUpRemote((_) async => jsonBody({'recent_completions': []}));

      await remote.analytics(trainerId);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, ApiEndpoints.clientTrainerAnalytics(trainerId));
      expect(request.path, isNot(contains('sig=')));
      expect(request.queryParameters, isEmpty);
    });

    test('результат с записью и ответом тренера', () async {
      final sample = jsonDecode(File('docs/samples/client_analytics.json').readAsStringSync());
      setUpRemote((_) async => jsonBody(sample as Object));

      final analytics = await remote.analytics(trainerId);

      expect(analytics.recentCompletions.first.comments.single.text, contains('Хорошая работа'));
    });

    test('ошибки: 404 client_not_found — связи нет, остальное по code', () async {
      final cases = <int, ({Object body, Type failure})>{
        404: (body: {'code': ApiErrorCodes.clientNotFound}, failure: WorkoutNotLinkedFailure),
        400: (body: {'code': 'bad_request'}, failure: WorkoutInvalidRequestFailure),
        401: (body: {'code': ApiErrorCodes.invalidToken}, failure: WorkoutSessionExpiredFailure),
        429: (body: {'code': ApiErrorCodes.rateLimited}, failure: WorkoutTooManyRequestsFailure),
        503: (body: {'code': 'x'}, failure: WorkoutServerUnavailableFailure),
        500: (body: {'code': 'x'}, failure: WorkoutUnknownFailure),
      };

      for (final entry in cases.entries) {
        setUpRemote((_) async => jsonBody(entry.value.body, status: entry.key));

        await expectLater(
          remote.analytics(trainerId),
          throwsA(predicate((e) => e.runtimeType == entry.value.failure)),
          reason: '${entry.key}',
        );
      }
    });

    test('тело не объект — Unknown; обрыв связи — Network', () async {
      for (final body in <Object>[[1], 'text']) {
        setUpRemote((_) async => jsonBody(body));
        await expectLater(remote.analytics(trainerId), throwsA(isA<WorkoutUnknownFailure>()));
      }

      setUpRemote(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(remote.analytics(trainerId), throwsA(isA<WorkoutNetworkFailure>()));
    });
  });
}
