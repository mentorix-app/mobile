import 'dart:ui';

import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/features/locale/domain/repositories/locale_repository.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleRepositoryImpl implements LocaleRepository {
  LocaleRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  /// Значение для «Системный».
  static const system = 'system';

  @override
  Locale? load() {
    final stored = _prefs.getString(StorageKeys.localeMode);

    // Неизвестное значение (в том числе язык, которого в приложении больше нет) —
    // «Системный».
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == stored) return locale;
    }
    return null;
  }

  @override
  Future<void> save(Locale? locale) =>
      _prefs.setString(StorageKeys.localeMode, locale?.languageCode ?? system);
}
