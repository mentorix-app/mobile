import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';
import 'package:mentorix_app/core/network/masked_talker_dio_logger.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/talker_capture.dart';

const _secrets = [
  'SECRET-ACCESS',
  'SECRET-REFRESH',
  'SECRET-ID-TOKEN',
  'SECRET-APPLE-ID-TOKEN',
  'SECRET-APPLE-AUTH-CODE',
  'SECRET-TELEGRAM-CODE',
  'SECRET-BEARER',
  'SECRET-NESTED',
];

void main() {
  late FakeHttpAdapter adapter;
  late Dio dio;

  void setUpDio(FakeResponder responder) {
    adapter = FakeHttpAdapter(responder);
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.test',
        contentType: Headers.jsonContentType,
      ),
    )..httpClientAdapter = adapter;

    // Как AuthInterceptor: Bearer подставляется до логгера.
    dio.interceptors
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['Authorization'] = 'Bearer SECRET-BEARER';
            handler.next(options);
          },
        ),
      )
      ..add(MaskedTalkerDioLogger(talker: AppTalker.instance));
  }

  void expectNoSecrets() {
    final output = loggedText().join('\n');
    for (final secret in _secrets) {
      expect(output, isNot(contains(secret)), reason: 'в логе $secret');
    }
  }

  setUp(resetTalker);

  test('вход: токены в запросе и ответе, в том числе вложенные', () async {
    setUpDio(
      (_) async => jsonBody({
        'access_token': 'SECRET-ACCESS',
        'refresh_token': 'SECRET-REFRESH',
        'token_type': 'Bearer',
        'user_id': 'user-1',
        'session': {
          'history': [
            {'access_token': 'SECRET-NESTED'},
          ],
        },
      }),
    );

    final response = await dio.post<Object?>(
      ApiEndpoints.authGoogle,
      data: {'id_token': 'SECRET-ID-TOKEN'},
    );

    expectNoSecrets();

    final output = loggedText().join('\n');
    expect(output, contains('***'));
    expect(output, contains('user-1'), reason: 'остальное остаётся видным');
    expect(output, contains('Authorization'));

    // Приложение получило настоящие значения — маскируется только лог.
    expect((response.data as Map)['access_token'], 'SECRET-ACCESS');
  });

  test('метод, путь, статус, время и заголовки на месте', () async {
    setUpDio((_) async => jsonBody({'items': <Object>[]}));

    await dio.get<Object?>(ApiEndpoints.clientTrainers);

    final output = loggedText().join('\n');
    expect(output, contains('[GET]'));
    expect(output, contains('/client/trainers'));
    expect(output, contains('Status: 200'));
    expect(output, contains('Time:'));
    expect(output, contains('Headers:'));
    expect(output, contains('Authorization'));
  });

  test('настоящий запрос уходит без изменений', () async {
    setUpDio((_) async => jsonBody({'ok': true}));

    await dio.post<Object?>(
      ApiEndpoints.authApple,
      data: {'id_token': 'SECRET-ID-TOKEN', 'name': 'Ivan'},
    );

    final sent = adapter.requests.single;
    expect(sent.headers['Authorization'], 'Bearer SECRET-BEARER');
    expect(sent.data, {'id_token': 'SECRET-ID-TOKEN', 'name': 'Ivan'});
    expectNoSecrets();
  });

  test('удаление аккаунта: токен и код Apple скрыты', () async {
    setUpDio((_) async => ResponseBody.fromString('', 204));

    await dio.delete<Object?>(
      ApiEndpoints.authMe,
      data: {
        'apple_id_token': 'SECRET-APPLE-ID-TOKEN',
        'apple_authorization_code': 'SECRET-APPLE-AUTH-CODE',
        'apple_redirect_uri': 'https://api.test/auth/apple/callback',
      },
    );

    expectNoSecrets();
    expect(
      loggedText().join('\n'),
      contains('apple_redirect_uri'),
      reason: 'адрес — не секрет',
    );
  });

  test('привязка Telegram: code в запросе скрыт', () async {
    setUpDio((_) async => jsonBody({'access_token': 'SECRET-ACCESS'}));

    await dio.post<Object?>(
      ApiEndpoints.authTelegramLink,
      data: {'code': 'SECRET-TELEGRAM-CODE'},
    );

    expectNoSecrets();
  });

  test('ошибка привязки Telegram: код ошибки виден, код привязки скрыт', () async {
    setUpDio(
      (_) async => jsonBody({
        'code': 'invalid_link_code',
        'message': 'invalid code',
      }, status: 400),
    );

    await expectLater(
      dio.post<Object?>(
        ApiEndpoints.authTelegramLink,
        data: {'code': 'SECRET-TELEGRAM-CODE'},
      ),
      throwsA(isA<DioException>()),
    );

    expectNoSecrets();
    final output = loggedText().join('\n');
    expect(output, contains('invalid_link_code'));
    expect(output, contains('Status: 400'));
  });

  test('ошибка с токенами в теле ответа: скрыты, исключение настоящее', () async {
    setUpDio(
      (_) async => jsonBody({
        'code': 'bad_request',
        'details': {'refresh_token': 'SECRET-REFRESH'},
      }, status: 400),
    );

    final error = await dio
        .post<Object?>(ApiEndpoints.authLogout, data: {
          'refresh_token': 'SECRET-REFRESH',
        })
        .then<DioException?>((_) => null)
        .onError<DioException>((e, _) => e);

    expectNoSecrets();
    expect(
      ((error!.response!.data as Map)['details'] as Map)['refresh_token'],
      'SECRET-REFRESH',
      reason: 'вызывающий код получает ответ как есть',
    );
  });

  test('сбой без ответа: запись есть, секретов нет', () async {
    setUpDio(
      (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      ),
    );

    await expectLater(
      dio.post<Object?>(ApiEndpoints.authGoogle, data: {
        'id_token': 'SECRET-ID-TOKEN',
      }),
      throwsA(isA<DioException>()),
    );

    expectNoSecrets();
    expect(loggedText().join('\n'), contains('/auth/google'));
  });
}
