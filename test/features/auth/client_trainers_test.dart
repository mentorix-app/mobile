import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

import '../../helpers/fake_http_adapter.dart';

/// `GET /client/trainers` на уровне датасорса: пустой и непустой `items`,
/// пустое имя, ошибки по `code`.
void main() {
  late FakeHttpAdapter adapter;

  AuthRemoteDataSource create(FakeResponder responder) {
    adapter = FakeHttpAdapter(responder);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    return AuthRemoteDataSource(apiDio: dio);
  }

  test('пустой items → тренеров нет', () async {
    final remote = create((_) async => jsonBody({'items': <Object>[]}));

    final trainers = await remote.getTrainers();

    expect(trainers, isEmpty);
    expect(adapter.requestsTo(ApiEndpoints.clientTrainers), hasLength(1));
    expect(adapter.requests.single.method, 'GET');
  });

  test('непустой items → тренер с UUID, именем и датой привязки', () async {
    final remote = create(
      (_) async => jsonBody({
        'items': [
          {
            'trainer_id': '5f0c2b0e-0a52-4c7e-9a43-6a2d6c9f1b10',
            'trainer_display_name': 'Анна Тренер',
            'linked_at': '2026-10-12T06:15:00Z',
            'unknown_field': true,
          },
        ],
      }),
    );

    final trainers = await remote.getTrainers();

    expect(trainers, hasLength(1));
    expect(trainers.single.trainerId, '5f0c2b0e-0a52-4c7e-9a43-6a2d6c9f1b10');
    expect(trainers.single.trainerDisplayName, 'Анна Тренер');
    expect(trainers.single.linkedAt, DateTime.utc(2026, 10, 12, 6, 15));
  });

  test('trainer_display_name — пустая строка: тренер всё равно есть', () async {
    final remote = create(
      (_) async => jsonBody({
        'items': [
          {'trainer_id': 'trainer-1', 'trainer_display_name': ''},
        ],
      }),
    );

    final trainers = await remote.getTrainers();

    expect(trainers, hasLength(1));
    expect(trainers.single.trainerDisplayName, isEmpty);
  });

  test('items не массив → UnknownFailure, а не падение', () async {
    final remote = create((_) async => jsonBody({'items': 'нет'}));

    await expectLater(remote.getTrainers(), throwsA(isA<UnknownFailure>()));
  });

  test('user_not_found → AccountNotFoundFailure', () async {
    final remote = create(
      (_) async => jsonBody({
        'code': 'user_not_found',
        'message': 'user not found',
      }, status: 404),
    );

    await expectLater(
      remote.getTrainers(),
      throwsA(isA<AccountNotFoundFailure>()),
    );
  });

  test('rate_limited → TooManyRequestsFailure', () async {
    final remote = create(
      (_) async => jsonBody({
        'code': 'rate_limited',
        'message': 'too many requests',
      }, status: 429),
    );

    await expectLater(
      remote.getTrainers(),
      throwsA(isA<TooManyRequestsFailure>()),
    );
  });
}
