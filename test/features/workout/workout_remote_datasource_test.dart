import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/features/workout/data/datasources/workout_remote_datasource.dart';
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
}
