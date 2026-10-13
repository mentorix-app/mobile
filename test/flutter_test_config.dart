import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';

/// Общая настройка всех тестов: чистый Talker без вывода в консоль перед
/// каждым тестом (иначе вывод тестов тонет в оформленных строках Talker).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(AppTalker.reset);
  await testMain();
}
