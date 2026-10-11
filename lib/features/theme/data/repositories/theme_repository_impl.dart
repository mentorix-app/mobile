import 'package:flutter/material.dart';
import 'package:mentorix_app/features/theme/domain/repositories/theme_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранит выбор темы в `shared_preferences`: тема — не секрет и читается на старте.
class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(this._prefs);

  static const storageKey = 'theme_mode';

  final SharedPreferences _prefs;

  @override
  ThemeMode load() {
    final stored = _prefs.getString(storageKey);
    // Неизвестное значение (например, от будущей версии) — не повод падать.
    return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  @override
  Future<void> save(ThemeMode mode) => _prefs.setString(storageKey, mode.name);
}
