import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';
import 'package:mentorix_app/core/logging/debug_sample_fetcher.dart';
import 'package:mentorix_app/core/logging/secret_masker.dart';
import 'package:mentorix_app/core/network/masked_talker_dio_logger.dart';
import 'package:mentorix_app/core/widgets/debug_samples_screen.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/talker_capture.dart';

/// Образец для `docs/samples/client_analytics.json` должен быть настоящим ответом
/// сервера. Журнал запросов маскирует `result_text` и ответ тренера, но только в
/// своей копии: то, что копирует кнопка debug-экрана, замаскированным быть не
/// должно, иначе в образец попало бы `***`.
void main() {
  const trainerId = '404dd1be-d973-4b97-8294-28a9e1fe38a9';
  const result = 'Сделал 5x5 по 80 кг,\nпоследний подход тяжело';
  const reply = 'Хорошо, на следующей неделе добавь 2,5 кг';

  final analytics = {
    'client': {'client_user_id': 'u-1', 'display_name': ''},
    'recent_completions': [
      {
        'id': 'c-1',
        'week_number': 1,
        'day_number': 1,
        'result_text': result,
        'is_current_cycle': true,
        'comments': [
          {'id': 'k-1', 'text': reply, 'created_at': '2026-10-28T12:00:00Z'},
        ],
      },
    ],
    'expires_at': null,
  };

  late FakeHttpAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = FakeHttpAdapter((options) async {
      if (options.path == ApiEndpoints.clientTrainers) {
        return jsonBody({
          'items': [
            {'trainer_id': trainerId, 'trainer_display_name': 'Aziz'},
          ],
        });
      }
      return jsonBody(analytics);
    });
    // Как в приложении: основной Dio с журналом запросов.
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(MaskedTalkerDioLogger(talker: AppTalker.instance));
  });

  test('образец analytics содержит настоящий result_text и ответ тренера', () async {
    final sample = await DebugSampleFetcher(dio).analytics();

    expect(sample.status, 200);
    expect(sample.body, contains('Сделал 5x5 по 80 кг'));
    expect(sample.body, contains(reply));
    expect(sample.body, isNot(contains(SecretMasker.mask)));
    // И это тот же JSON, что прислал сервер.
    expect(jsonDecode(sample.body), analytics);
  });

  test('при этом в журнале запросов тексты скрыты: маскируется копия', () async {
    await DebugSampleFetcher(dio).analytics();

    final log = loggedText().join('\n');
    expect(log, contains('/analytics'));
    expect(log, isNot(contains('Сделал 5x5')));
    expect(log, isNot(contains('добавь 2,5 кг')));
    expect(log, contains(SecretMasker.mask));
  });

  testWidgets('кнопка debug-экрана кладёт в буфер обмена настоящий текст', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.runAsync(() async {});
    await tester.pumpWidget(
      MaterialApp(home: DebugSamplesScreen(fetcher: DebugSampleFetcher(dio))),
    );
    await tester.tap(find.text('GET /client/trainers/{id}/analytics'));
    await tester.pumpAndSettle();

    expect(clipboard, isNotNull);
    expect(clipboard, contains('Сделал 5x5 по 80 кг'));
    expect(clipboard, contains(reply));
    expect(clipboard, isNot(contains(SecretMasker.mask)));
    // На экране — тот же настоящий текст.
    expect(find.textContaining('Сделал 5x5 по 80 кг', findRichText: true), findsOneWidget);
  });

  test('запрос отметки уходит с настоящим текстом, в журнале он скрыт', () async {
    await dio.post<Object?>(
      ApiEndpoints.clientTrainerCompletions(trainerId),
      data: {'day_key': 'd', 'result_text': result},
    );

    expect(adapter.requests.last.data['result_text'], result);
    final log = loggedText().join('\n');
    expect(log, isNot(contains('Сделал 5x5')));
    expect(log, contains(SecretMasker.mask));
  });
}
