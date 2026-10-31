import 'dart:ui';

abstract class LocaleRepository {
  /// Сохранённый язык приложения; `null` — «Системный».
  Locale? load();

  Future<void> save(Locale? locale);
}
