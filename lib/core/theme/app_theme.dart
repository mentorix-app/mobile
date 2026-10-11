import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_text_theme.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Светлая и тёмная `ThemeData`, собранные из токенов `globals.css`.
abstract final class AppTheme {
  static final ThemeData light = _build(
    brightness: Brightness.light,
    tokens: AppThemeExtension.light,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    tokens: AppThemeExtension.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppThemeExtension tokens,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.primary,
      onPrimary: tokens.primaryForeground,
      secondary: tokens.secondary,
      onSecondary: tokens.secondaryForeground,
      error: tokens.destructive,
      // В globals.css нет destructive-foreground: берём primary-foreground —
      // он контрастен к destructive в обеих темах.
      onError: tokens.primaryForeground,
      surface: tokens.background,
      onSurface: tokens.foreground,
      onSurfaceVariant: tokens.mutedForeground,
      surfaceContainer: tokens.card,
      surfaceContainerHighest: tokens.muted,
      outline: tokens.border,
      outlineVariant: tokens.border,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      cardColor: tokens.card,
      dividerColor: tokens.border,
      textTheme: AppTextTheme.build(
        brightness: brightness,
        color: tokens.foreground,
      ),
      cardTheme: CardThemeData(
        color: tokens.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: tokens.border),
        ),
      ),
      extensions: [tokens],
    );
  }
}
