import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';
import 'package:mentorix_app/core/network/masked_talker_dio_logger.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/talker_capture.dart';

void main() {
  late Dio dio;

  /// Всё, что `print` вывел бы в консоль `flutter run`, пока выполняется [body].
  Future<String> consoleOutput(Future<void> Function() body) async {
    final lines = <String>[];
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    return lines.join('\n');
  }

  setUp(() {
    AppTalker.reset(console: true);
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = FakeHttpAdapter(
        (_) async => jsonBody({'id': 'user-1'}, headers: {'x-request-id': 'rid-42'}),
      )
      ..interceptors.add(MaskedTalkerDioLogger(talker: AppTalker.instance));
  });

  tearDown(() => AppTalker.reset());

  test('консоль: метод, путь, статус, время и тела, без заголовков', () async {
    final console = await consoleOutput(
      () => dio.post<Object?>(ApiEndpoints.authApple, data: {'name': 'Ivan'}),
    );

    expect(console, contains('[POST]'));
    expect(console, contains(ApiEndpoints.authApple));
    expect(console, contains('Status: 200'));
    expect(console, contains('Time:'));
    expect(console, contains('Ivan'), reason: 'тело запроса');
    expect(console, contains('user-1'), reason: 'тело ответа');
    expect(console, isNot(contains('Headers:')));
    expect(console, isNot(contains('x-request-id')));
    expect(console, isNot(contains('content-type')));
  });

  test('экран логов: заголовки остаются в записях', () async {
    await consoleOutput(() => dio.get<Object?>(ApiEndpoints.clientTrainers));

    final screen = loggedText().join('\n');
    expect(screen, contains('Headers:'));
    expect(screen, contains('x-request-id'));
  });

  test('обычные строки журнала консоль не меняет', () async {
    final console = await consoleOutput(() async {
      AppTalker.instance.debug('[mentorix.apple] name fallback: PATCH sent');
    });

    expect(console, contains('[mentorix.apple] name fallback: PATCH sent'));
  });
}
