import 'package:flutter/painting.dart';

/// Тёмная палитра — блок `.dark` из `globals.css`.
///
/// `oklch` переведён в HEX один раз здесь; в виджетах цвета берутся
/// из `AppThemeExtension` (`context.themeExt`), а не отсюда.
abstract final class AppColors {
  static const background = Color(0xFF0A0A0A);
  static const foreground = Color(0xFFFAFAFA);
  static const card = Color(0xFF171717);
  static const cardForeground = Color(0xFFFAFAFA);
  static const popover = Color(0xFF171717);
  static const popoverForeground = Color(0xFFFAFAFA);
  static const primary = Color(0xFFE5E5E5);
  static const primaryForeground = Color(0xFF171717);
  static const secondary = Color(0xFF262626);
  static const secondaryForeground = Color(0xFFFAFAFA);
  static const muted = Color(0xFF262626);
  static const mutedForeground = Color(0xFFA1A1A1);
  static const accent = Color(0xFF262626);
  static const accentForeground = Color(0xFFFAFAFA);
  static const destructive = Color(0xFFFF6467);
  static const border = Color.fromRGBO(255, 255, 255, 0.10);
  static const input = Color.fromRGBO(255, 255, 255, 0.15);
  static const ring = Color(0xFF737373);

  static const chart1 = Color(0xFFD4D4D4);
  static const chart2 = Color(0xFF737373);
  static const chart3 = Color(0xFF525252);
  static const chart4 = Color(0xFF404040);
  static const chart5 = Color(0xFF262626);

  // sidebar-* понадобятся в планшетной раскладке.
  static const sidebar = Color(0xFF171717);
  static const sidebarForeground = Color(0xFFFAFAFA);
  static const sidebarPrimary = Color(0xFF1447E6);
  static const sidebarPrimaryForeground = Color(0xFFFAFAFA);
  static const sidebarAccent = Color(0xFF262626);
  static const sidebarAccentForeground = Color(0xFFFAFAFA);
  static const sidebarBorder = Color.fromRGBO(255, 255, 255, 0.10);
  static const sidebarRing = Color(0xFF737373);
}
