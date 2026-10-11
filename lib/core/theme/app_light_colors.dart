import 'package:flutter/painting.dart';

/// Светлая палитра — блок `:root` из `globals.css`.
///
/// Имена совпадают с `AppColors` (тёмной палитрой).
abstract final class AppLightColors {
  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF0A0A0A);
  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF0A0A0A);
  static const popover = Color(0xFFFFFFFF);
  static const popoverForeground = Color(0xFF0A0A0A);
  static const primary = Color(0xFF171717);
  static const primaryForeground = Color(0xFFFAFAFA);
  static const secondary = Color(0xFFF5F5F5);
  static const secondaryForeground = Color(0xFF171717);
  static const muted = Color(0xFFF5F5F5);
  static const mutedForeground = Color(0xFF737373);
  static const accent = Color(0xFFF5F5F5);
  static const accentForeground = Color(0xFF171717);
  static const destructive = Color(0xFFE7000B);
  static const border = Color(0xFFE5E5E5);
  static const input = Color(0xFFE5E5E5);
  static const ring = Color(0xFFA1A1A1);

  static const chart1 = Color(0xFFD4D4D4);
  static const chart2 = Color(0xFF737373);
  static const chart3 = Color(0xFF525252);
  static const chart4 = Color(0xFF404040);
  static const chart5 = Color(0xFF262626);

  // sidebar-* понадобятся в планшетной раскладке.
  static const sidebar = Color(0xFFFAFAFA);
  static const sidebarForeground = Color(0xFF0A0A0A);
  static const sidebarPrimary = Color(0xFF171717);
  static const sidebarPrimaryForeground = Color(0xFFFAFAFA);
  static const sidebarAccent = Color(0xFFF5F5F5);
  static const sidebarAccentForeground = Color(0xFF171717);
  static const sidebarBorder = Color(0xFFE5E5E5);
  static const sidebarRing = Color(0xFFA1A1A1);
}
