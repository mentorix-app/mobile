import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/api_log_interceptor.dart';
import 'package:mentorix_app/core/network/dio_factory.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http_adapter.dart';

/// `kDebugMode` в тестах всегда `true`, поэтому release имитируется через
/// `DebugLog.debugModeOverride = false`: все проверки идут через ту же
/// проверку режима, что и в приложении.
void main() {
  late List<String> printed;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    printed = [];
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    DebugLog.debugModeOverride = null;
  });

  group('debug-сборка: строки видны в консоли (debugPrint)', () {
    test('DebugLog пишет строку с тегом', () {
      DebugLog.write('mentorix.http', 'GET /auth/me 200');

      expect(printed, ['[mentorix.http] GET /auth/me 200']);
    });

    test('AppLogger в debug идёт через debugPrint, а не только в developer', () {
      AppLogger.warning('предупреждение');
      AppLogger.error('сбой', StateError('причина'));
      AppLogger.http('GET /x 200');

      expect(printed, hasLength(3));
      expect(printed[0], '[mentorix] WARNING предупреждение');
      expect(printed[1], contains('ERROR сбой'));
      expect(printed[2], '[mentorix.http] GET /x 200');
    });

    test('ApiLogInterceptor по умолчанию пишет в консоль', () async {
      final adapter = FakeHttpAdapter(
        (_) async => jsonBody({'code': 'rate_limited'}, status: 429),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiLogInterceptor());

      await expectLater(
        dio.get<Object?>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      expect(printed, hasLength(1));
      expect(
        printed.single,
        matches(r'^\[mentorix\.http\] \d{4}-\d{2}-\d{2}T[\d:.]+Z GET /auth/me 429 code=rate_limited$'),
      );
    });

    test('createApiDio и createPlainDio подключают журнал', () async {
      SharedPreferences.setMockInitialValues({});
      final tokens = TokenStorage(
        const FlutterSecureStorage(),
        await SharedPreferences.getInstance(),
      );
      final plain = createPlainDio();
      final api = createApiDio(
        plainDio: plain,
        tokens: tokens,
        sessionExpired: SessionExpiredNotifier(),
      );

      expect(plain.interceptors.whereType<ApiLogInterceptor>(), hasLength(1));
      expect(api.interceptors.whereType<ApiLogInterceptor>(), hasLength(1));
    });
  });

  group('release: ничего не логируется', () {
    setUp(() => DebugLog.debugModeOverride = false);

    test('DebugLog и yes/no ничего не пишут', () {
      DebugLog.write('mentorix.apple', 'givenName="Ivan"');

      expect(printed, isEmpty);
    });

    test('AppLogger не пользуется debugPrint', () {
      AppLogger.warning('предупреждение');
      AppLogger.error('сбой', StateError('причина'));
      AppLogger.http('GET /x 200');

      expect(printed, isEmpty);
    });

    test('ApiLogInterceptor молчит, даже если подключён', () async {
      final adapter = FakeHttpAdapter(
        (_) async => jsonBody({'code': 'rate_limited'}, status: 429),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiLogInterceptor());

      await expectLater(
        dio.get<Object?>('/auth/me'),
        throwsA(isA<DioException>()),
      );
      await dio.get<Object?>('/ok').onError((_, _) => Response(
        requestOptions: RequestOptions(path: '/ok'),
      ));

      expect(printed, isEmpty);
    });

    test('интерцептор сам не вызывает приёмник строк в release', () async {
      final lines = <String>[];
      final adapter = FakeHttpAdapter(
        (_) async => jsonBody({'code': 'rate_limited'}, status: 429),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiLogInterceptor(sink: lines.add));

      await expectLater(
        dio.get<Object?>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      expect(lines, isEmpty);
    });

    test('createApiDio и createPlainDio не подключают журнал', () async {
      SharedPreferences.setMockInitialValues({});
      final tokens = TokenStorage(
        const FlutterSecureStorage(),
        await SharedPreferences.getInstance(),
      );
      final plain = createPlainDio();
      final api = createApiDio(
        plainDio: plain,
        tokens: tokens,
        sessionExpired: SessionExpiredNotifier(),
      );

      expect(plain.interceptors.whereType<ApiLogInterceptor>(), isEmpty);
      expect(api.interceptors.whereType<ApiLogInterceptor>(), isEmpty);
    });
  });
}
