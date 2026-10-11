/// Отступы.
///
/// Первые три значения — токены дизайнеров из `globals.css` (мобильный вариант).
/// Шкала ниже — уровень приложения: в `globals.css` её нет, и при первой же
/// возможности её стоит согласовать с дизайнерами.
abstract final class AppSpacing {
  /// `--app-content-px`: горизонтальный отступ контента.
  static const double contentHorizontal = 9;

  /// `--app-content-py`: вертикальный отступ контента.
  static const double contentVertical = 8;

  /// `--app-header-height`.
  static const double headerHeight = 56;

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}
