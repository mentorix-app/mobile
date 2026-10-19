import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/dashboard_config.dart';
import 'package:mentorix_app/features/mode/presentation/cubit/dashboard_link_cubit.dart';

import '../../helpers/fake_external_link_launcher.dart';

/// Адрес веб-кабинета приходит из `config/stage.json` (ключ `DASHBOARD_URL`).
void main() {
  late String stageUrl;

  setUpAll(() {
    final stage =
        jsonDecode(File('config/stage.json').readAsStringSync())
            as Map<String, dynamic>;
    stageUrl = stage['DASHBOARD_URL'] as String;
  });

  test('в config/stage.json есть ключ DASHBOARD_URL с настоящим адресом', () {
    expect(stageUrl, isNotEmpty);
    expect(stageUrl, startsWith('https://'));
    expect(DashboardConfig.isRealUrl(stageUrl), isTrue);
    expect(
      DashboardLinkCubit(FakeExternalLinkLauncher(), url: stageUrl).isConfigured,
      isTrue,
      reason: 'с этим адресом кнопка «Открыть дашборд» активна',
    );
  });

  test('без --dart-define адрес — плейсхолдер, с ним — из stage.json', () {
    expect(
      DashboardConfig.url,
      anyOf(DashboardConfig.urlPlaceholder, stageUrl),
    );
  });

  // Запуск: flutter test --dart-define-from-file=config/stage.json
  test(
    'сборка со stage.json: адрес настоящий, кубит настроен по умолчанию',
    () {
      expect(DashboardConfig.url, stageUrl);
      expect(DashboardConfig.isConfigured, isTrue);
      expect(DashboardLinkCubit(FakeExternalLinkLauncher()).isConfigured, isTrue);
    },
    skip: DashboardConfig.url == DashboardConfig.urlPlaceholder
        ? 'запуск без --dart-define-from-file'
        : false,
  );

  group('parse', () {
    test('https-адрес', () {
      expect(
        DashboardConfig.parse('https://dashboard.mentorix.app/'),
        Uri.parse('https://dashboard.mentorix.app/'),
      );
    });

    test('http-адрес тоже годится (локальный стенд)', () {
      expect(DashboardConfig.isRealUrl('http://localhost:3000'), isTrue);
    });

    for (final bad in [
      '',
      DashboardConfig.urlPlaceholder,
      'dashboard.mentorix.app',
      'ftp://dashboard.mentorix.app',
      'javascript:alert(1)',
      'https://',
    ]) {
      test('«$bad» — адрес не задан', () {
        expect(DashboardConfig.parse(bad), isNull);
        expect(DashboardConfig.isRealUrl(bad), isFalse);
      });
    }
  });
}
