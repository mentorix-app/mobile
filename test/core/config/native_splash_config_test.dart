import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/theme/app_colors.dart';
import 'package:mentorix_app/core/theme/app_light_colors.dart';

/// Нативный сплеш рисуется до запуска Flutter и берёт цвета из
/// `flutter_native_splash.yaml`. Фон должен совпадать с токеном `background`,
/// иначе при переходе к SplashScreen экран мигнёт другим цветом.
void main() {
  late String config;

  setUpAll(() => config = File('flutter_native_splash.yaml').readAsStringSync());

  String hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  String? value(String key, {String indent = '  '}) {
    // Значение в кавычках (там бывает «#») либо «голое» слово без комментария.
    final match = RegExp(
      '^$indent$key:\\s*(?:"([^"]*)"|([^\\s#]+))',
      multiLine: true,
    ).firstMatch(config);
    return (match?.group(1) ?? match?.group(2))?.trim();
  }

  test('фон — токены background светлой и тёмной темы', () {
    expect(value('color'), hex(AppLightColors.background));
    expect(value('color_dark'), hex(AppColors.background));
  });

  test('Android 12: фон и подложка иконки совпадают с токенами', () {
    const indent = '    ';
    expect(value('color', indent: indent), hex(AppLightColors.background));
    expect(value('color_dark', indent: indent), hex(AppColors.background));
    expect(
      value('icon_background_color', indent: indent),
      hex(AppLightColors.background),
    );
    expect(
      value('icon_background_color_dark', indent: indent),
      hex(AppColors.background),
    );
  });

  test('картинки из конфига существуют', () {
    for (final key in ['image', 'image_dark']) {
      final path = value(key);
      expect(path, isNotNull, reason: key);
      expect(File(path!).existsSync(), isTrue, reason: path);
    }
    expect(File(value('image', indent: '    ')!).existsSync(), isTrue);
  });
}
