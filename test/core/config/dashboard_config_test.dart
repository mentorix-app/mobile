import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/dashboard_config.dart';

/// Адрес веб-кабинета приходит из `config/stage.json` (ключ `DASHBOARD_URL`).
void main() {
  test('в config/stage.json есть ключ DASHBOARD_URL', () {
    final stage =
        jsonDecode(File('config/stage.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(stage['DASHBOARD_URL'], isA<String>());
    expect((stage['DASHBOARD_URL'] as String).isNotEmpty, isTrue);
  });

  test('без --dart-define адрес — плейсхолдер, кнопка неактивна', () {
    expect(DashboardConfig.url, DashboardConfig.urlPlaceholder);
    expect(DashboardConfig.isConfigured, isFalse);
  });

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
