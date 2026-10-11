import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_colors.dart';
import 'package:mentorix_app/core/theme/app_light_colors.dart';

/// Цветовые токены `globals.css`, доступные виджетам через `context.themeExt`.
///
/// Hex в виджетах не пишется: цвет берётся отсюда, и тёмная тема подхватывается
/// сама. Палитры лежат в `AppLightColors` и `AppColors`.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.border,
    required this.input,
    required this.ring,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
  });

  static const light = AppThemeExtension(
    background: AppLightColors.background,
    foreground: AppLightColors.foreground,
    card: AppLightColors.card,
    cardForeground: AppLightColors.cardForeground,
    popover: AppLightColors.popover,
    popoverForeground: AppLightColors.popoverForeground,
    primary: AppLightColors.primary,
    primaryForeground: AppLightColors.primaryForeground,
    secondary: AppLightColors.secondary,
    secondaryForeground: AppLightColors.secondaryForeground,
    muted: AppLightColors.muted,
    mutedForeground: AppLightColors.mutedForeground,
    accent: AppLightColors.accent,
    accentForeground: AppLightColors.accentForeground,
    destructive: AppLightColors.destructive,
    border: AppLightColors.border,
    input: AppLightColors.input,
    ring: AppLightColors.ring,
    chart1: AppLightColors.chart1,
    chart2: AppLightColors.chart2,
    chart3: AppLightColors.chart3,
    chart4: AppLightColors.chart4,
    chart5: AppLightColors.chart5,
  );

  static const dark = AppThemeExtension(
    background: AppColors.background,
    foreground: AppColors.foreground,
    card: AppColors.card,
    cardForeground: AppColors.cardForeground,
    popover: AppColors.popover,
    popoverForeground: AppColors.popoverForeground,
    primary: AppColors.primary,
    primaryForeground: AppColors.primaryForeground,
    secondary: AppColors.secondary,
    secondaryForeground: AppColors.secondaryForeground,
    muted: AppColors.muted,
    mutedForeground: AppColors.mutedForeground,
    accent: AppColors.accent,
    accentForeground: AppColors.accentForeground,
    destructive: AppColors.destructive,
    border: AppColors.border,
    input: AppColors.input,
    ring: AppColors.ring,
    chart1: AppColors.chart1,
    chart2: AppColors.chart2,
    chart3: AppColors.chart3,
    chart4: AppColors.chart4,
    chart5: AppColors.chart5,
  );

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color border;
  final Color input;
  final Color ring;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;

  @override
  AppThemeExtension copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? popover,
    Color? popoverForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? border,
    Color? input,
    Color? ring,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
  }) {
    return AppThemeExtension(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      popover: popover ?? this.popover,
      popoverForeground: popoverForeground ?? this.popoverForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      border: border ?? this.border,
      input: input ?? this.input,
      ring: ring ?? this.ring,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chart5: chart5 ?? this.chart5,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
      popover: Color.lerp(popover, other.popover, t)!,
      popoverForeground: Color.lerp(
        popoverForeground,
        other.popoverForeground,
        t,
      )!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(accentForeground, other.accentForeground, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      chart1: Color.lerp(chart1, other.chart1, t)!,
      chart2: Color.lerp(chart2, other.chart2, t)!,
      chart3: Color.lerp(chart3, other.chart3, t)!,
      chart4: Color.lerp(chart4, other.chart4, t)!,
      chart5: Color.lerp(chart5, other.chart5, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeExtension get themeExt =>
      Theme.of(this).extension<AppThemeExtension>()!;
}
