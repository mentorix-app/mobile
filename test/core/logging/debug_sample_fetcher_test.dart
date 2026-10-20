import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/debug_sample_fetcher.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  const trainerId = '11111111-1111-1111-1111-111111111111';

  late FakeHttpAdapter adapter;
  late DebugSampleFetcher fetcher;

  void setUpFetcher(FakeResponder responder) {
    adapter = FakeHttpAdapter(responder);
    fetcher = DebugSampleFetcher(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );
  }

  test('trainers: статус и JSON с отступами, ключи в порядке сервера', () async {
    setUpFetcher(
      (_) async => jsonBody({
        'items': [
          {'trainer_id': trainerId, 'trainer_display_name': 'Coach'},
        ],
      }),
    );

    final sample = await fetcher.trainers();

    expect(sample.path, ApiEndpoints.clientTrainers);
    expect(sample.status, 200);
    expect(sample.body, contains('\n  "items": ['));
    expect(sample.body.indexOf('trainer_id'),
        lessThan(sample.body.indexOf('trainer_display_name')));
  });

  test('program: берёт id первого тренера и просит тело строкой', () async {
    setUpFetcher((options) async {
      if (options.path == ApiEndpoints.clientTrainers) {
        return jsonBody({
          'items': [
            {'trainer_id': trainerId, 'trainer_display_name': 'Coach'},
          ],
        });
      }
      return jsonBody({'assignment': null, 'program': null, 'completed_days': []});
    });

    final sample = await fetcher.program();

    expect(sample.path, ApiEndpoints.clientTrainerProgram(trainerId));
    expect(sample.body, contains('"completed_days": []'));
    expect(
      adapter.requests.every((r) => r.responseType == ResponseType.plain),
      isTrue,
    );
  });

  test('program: ошибка API тоже образец (403 client_not_linked)', () async {
    setUpFetcher((options) async {
      if (options.path == ApiEndpoints.clientTrainers) {
        return jsonBody({
          'items': [
            {'trainer_id': trainerId},
          ],
        });
      }
      return jsonBody({'code': 'client_not_linked', 'message': 'x'}, status: 403);
    });

    final sample = await fetcher.program();

    expect(sample.status, 403);
    expect(sample.body, contains('client_not_linked'));
  });

  test('program: тренеров нет — запрос программы не уходит', () async {
    setUpFetcher((_) async => jsonBody({'items': []}));

    final sample = await fetcher.program();

    expect(sample.status, isNull);
    expect(adapter.requests, hasLength(1));
  });

  test('не JSON — тело как есть', () async {
    setUpFetcher((_) async => ResponseBody.fromString('<html>', 502));

    final sample = await fetcher.trainers();

    expect(sample.status, 502);
    expect(sample.body, '<html>');
  });

  test('эндпоинт программы', () {
    expect(
      ApiEndpoints.clientTrainerProgram(trainerId),
      '/client/trainers/$trainerId/program',
    );
  });
}
