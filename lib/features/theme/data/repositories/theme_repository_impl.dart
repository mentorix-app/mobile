import 'package:flutter/material.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/features/theme/domain/repositories/theme_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  ThemeMode load() {
    final stored = _prefs.getString(StorageKeys.themeMode);
    return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  @override
  Future<void> save(ThemeMode mode) => _prefs.setString(StorageKeys.themeMode, mode.name);
}
