import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/network/api_log_interceptor.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late List<String> lines;
  late FakeHttpAdapter adapter;
  late Dio dio;

  void setUpDio(FakeResponder responder) {
    lines = [];
    adapter = FakeHttpAdapter(responder);
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        ApiLogInterceptor(
          sink: lines.add,
          now: () => DateTime.utc(2026, 10, 13, 9, 30, 15),
        ),
      );
  }

  test('успешный ответ: время, метод, путь, статус', () async {
    setUpDio((_) async => jsonBody({'items': <Object>[]}));

    await dio.get<Object?>(ApiEndpoints.clientTrainers);

    expect(lines, ['2026-10-13T09:30:15.000Z GET /client/trainers 200']);
  });

  test('ошибка: в строке есть code из ответа', () async {
    setUpDio(
      (_) async => jsonBody({
        'code': 'invite_consumed',
        'message': 'секретный текст',
      }, status: 409),
    );

    await expectLater(
      dio.post<Object?>(ApiEndpoints.clientInviteAccept, data: {'token': 't'}),
      throwsA(isA<DioException>()),
    );

    expect(lines, [
      '2026-10-13T09:30:15.000Z POST /client/invites/accept 409 '
          'code=invite_consumed',
    ]);
  });

  test('message, тело запроса и токены в строку не попадают', () async {
    setUpDio(
      (_) async => jsonBody({'code': 'invalid_token', 'message': 'SECRET'},
          status: 401),
    );

    await expectLater(
      dio.get<Object?>(
        ApiEndpoints.authMe,
        options: Options(headers: {'Authorization': 'Bearer top-secret'}),
      ),
      throwsA(isA<DioException>()),
    );

    final line = lines.single;
    expect(line, isNot(contains('SECRET')));
    expect(line, isNot(contains('top-secret')));
    expect(line, contains('code=invalid_token'));
  });

  test('ошибка без code в теле: только статус', () async {
    setUpDio((_) async => jsonBody('Internal Server Error', status: 500));

    await expectLater(
      dio.get<Object?>(ApiEndpoints.authMe),
      throwsA(isA<DioException>()),
    );

    expect(lines.single, endsWith('GET /auth/me 500'));
  });

  test('нет связи: вместо статуса — тип ошибки', () async {
    setUpDio(
      (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      ),
    );

    await expectLater(
      dio.get<Object?>(ApiEndpoints.authMe),
      throwsA(isA<DioException>()),
    );

    expect(lines.single, endsWith('GET /auth/me connectionError'));
  });
}
