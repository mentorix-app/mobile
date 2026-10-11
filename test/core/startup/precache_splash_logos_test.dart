import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/startup/precache_splash_logos.dart';
import 'package:mentorix_app/generated/assets.dart';

void main() {
  testWidgets('логотипы обоих вариантов оказываются в ImageCache', (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache..clear();

    for (final asset in [Assets.splashFullLogo, Assets.splashFullLogoDark]) {
      final key = await AssetImage(asset).obtainKey(ImageConfiguration.empty);
      expect(cache.containsKey(key), isFalse, reason: '$asset до прогрева');
    }

    await tester.runAsync(precacheSplashLogos);

    for (final asset in [Assets.splashFullLogo, Assets.splashFullLogoDark]) {
      final key = await AssetImage(asset).obtainKey(ImageConfiguration.empty);
      expect(cache.containsKey(key), isTrue, reason: '$asset после прогрева');
    }
  });

  testWidgets('несуществующий файл: загрузка завершается, запуск не падает', (
    tester,
  ) async {
    var completed = false;

    await tester.runAsync(() async {
      await preloadImage(const AssetImage('assets/splash/missing.png'));
      completed = true;
    });

    expect(completed, isTrue);
  });
}
