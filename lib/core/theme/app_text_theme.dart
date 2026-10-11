import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Текстовая шкала: размеры — мобильная колонка `globals.css`
/// (`--fs-*` в `@media (max-width: 768px)`), шрифт — Inter.
///
/// Начертания в `globals.css` не заданы: заголовки h1–h5 — `w600`, остальное —
/// `w400`. Слоты `TextTheme`, которых нет в таблице (`display*`, `titleSmall`,
/// `labelLarge`, `labelMedium`), остаются Material-умолчаниями.
abstract final class AppTextTheme {
  static const double h1 = 24;
  static const double h2 = 20;
  static const double h3 = 18;
  static const double h4 = 16;
  static const double h5 = 15;
  static const double pLg = 16;
  static const double p = 16;
  static const double pSm = 13;
  static const double pXs = 12;

  static TextTheme build({
    required Brightness brightness,
    required Color color,
  }) {
    final base = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    TextStyle? scale(TextStyle? style, double size, FontWeight weight) =>
        style?.copyWith(fontSize: size, fontWeight: weight);

    return base
        .copyWith(
          headlineLarge: scale(base.headlineLarge, h1, FontWeight.w600),
          headlineMedium: scale(base.headlineMedium, h2, FontWeight.w600),
          headlineSmall: scale(base.headlineSmall, h3, FontWeight.w600),
          titleLarge: scale(base.titleLarge, h4, FontWeight.w600),
          titleMedium: scale(base.titleMedium, h5, FontWeight.w600),
          bodyLarge: scale(base.bodyLarge, pLg, FontWeight.w400),
          bodyMedium: scale(base.bodyMedium, p, FontWeight.w400),
          bodySmall: scale(base.bodySmall, pSm, FontWeight.w400),
          labelSmall: scale(base.labelSmall, pXs, FontWeight.w400),
        )
        .apply(bodyColor: color, displayColor: color);
  }
}
