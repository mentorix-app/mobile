import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/dio_factory.dart';
import 'package:mentorix_app/core/network/masked_talker_dio_logger.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/talker_capture.dart';

/// `kDebugMode` в тестах всегда `true`, поэтому release имитируется через
/// `DebugLog.debugModeOverride = false`: все проверки идут через ту же
/// проверку режима, что и в приложении.
void main() {
  setUp(resetTalker);

  tearDown(() => DebugLog.debugModeOverride = null);

  Future<({Dio plain, Dio api})> createClients() async {
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
    return (plain: plain, api: api);
  }

  group('debug-сборка: всё идёт через Talker', () {
    test('DebugLog пишет строку с тегом', () {
      DebugLog.write('mentorix.http', 'GET /auth/me 200');

      expect(loggedMessages(), ['[mentorix.http] GET /auth/me 200']);
    });

    test('AppLogger пишет в Talker, интерфейс прежний', () {
      AppLogger.warning('предупреждение');
      AppLogger.error('сбой', StateError('причина'));
      AppLogger.http('GET /x 200');

      final data = AppTalker.instance.history;
      expect(data, hasLength(3));
      expect(data[0].message, 'предупреждение');
      expect(data[0].logLevel?.name, 'warning');
      expect(data[1].message, 'сбой');
      expect(data[1].logLevel?.name, 'error');
      expect(data[2].message, '[mentorix.http] GET /x 200');
    });

    test('createApiDio и createPlainDio подключают TalkerDioLogger', () async {
      final clients = await createClients();

      expect(
        clients.plain.interceptors.whereType<MaskedTalkerDioLogger>(),
        hasLength(1),
      );
      expect(
        clients.api.interceptors.whereType<MaskedTalkerDioLogger>(),
        hasLength(1),
      );
    });

    test('в основном Dio логгер стоит после AuthInterceptor', () async {
      // Иначе к моменту записи заголовок Authorization ещё не подставлен.
      final clients = await createClients();
      final types = clients.api.interceptors.map((i) => i.runtimeType).toList();

      expect(
        types.indexOf(MaskedTalkerDioLogger),
        greaterThan(types.indexWhere((t) => t.toString() == 'AuthInterceptor')),
      );
    });
  });

  group('release: ни логов, ни перехватчика', () {
    setUp(() => DebugLog.debugModeOverride = false);

    test('DebugLog и AppLogger ничего не пишут и Talker не создаётся', () {
      DebugLog.write('mentorix.apple', 'givenName="Ivan"');
      AppLogger.warning('предупреждение');
      AppLogger.error('сбой', StateError('причина'));
      AppLogger.http('GET /x 200');

      expect(AppTalker.isCreated, isFalse);
      expect(loggedMessages(), isEmpty);
    });

    test('Dio создаются без логгера', () async {
      final clients = await createClients();

      expect(
        clients.plain.interceptors.whereType<MaskedTalkerDioLogger>(),
        isEmpty,
      );
      expect(
        clients.api.interceptors.whereType<MaskedTalkerDioLogger>(),
        isEmpty,
      );
      expect(AppTalker.isCreated, isFalse);
    });
  });
}
