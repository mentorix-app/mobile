import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mentorix_app/generated/assets.dart';

/// Прогревает логотипы Flutter-сплеша в `ImageCache` до первого кадра.
///
/// Нативный экран исчезает на первом кадре Flutter. Если картинка ещё не
/// декодирована, этот кадр рисуется без логотипа, и логотип «мигает».
/// С прогретым кэшем `Image.asset` рисует его уже в первом кадре.
///
/// Прогреваются оба варианта: тема выбирается по системной, но пользователь
/// мог сохранить свою.
Future<void> precacheSplashLogos() {
  return Future.wait([
    Assets.splashFullLogo,
    Assets.splashFullLogoDark,
  ].map((asset) => preloadImage(AssetImage(asset))));
}

/// Загружает картинку в `ImageCache` без `BuildContext`. Завершается и при
/// ошибке загрузки: сплеш в этом случае просто нарисуется позже, а запуск
/// приложения из-за него падать не должен.
Future<void> preloadImage(ImageProvider provider) {
  final done = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);

  late final ImageStreamListener listener;
  void finish() {
    if (!done.isCompleted) done.complete();
    stream.removeListener(listener);
  }

  listener = ImageStreamListener((_, _) => finish(), onError: (_, _) => finish());
  stream.addListener(listener);
  return done.future;
}
