import 'package:flutter/material.dart';

abstract class ThemeRepository {
  /// Сохранённый выбор темы; `ThemeMode.system`, если ничего не сохранено.
  ThemeMode load();

  Future<void> save(ThemeMode mode);
}
