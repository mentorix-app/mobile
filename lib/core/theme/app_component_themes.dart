import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Темы компонентов Material: стиль shadcn из токенов `globals.css` и `AppRadii`.
///
/// Своих цветов и размеров здесь нет: цвет — только из [AppThemeExtension],
/// радиусы — из [AppRadii], отступы — из [AppSpacing]. Брендовых цветов логотипа
/// интерфейс не использует (`BRAND.md`).
abstract final class AppComponentThemes {
  /// Минимальная высота кнопок: целевая область нажатия ≥ 48.
  static const double _buttonHeight = 48;

  static AppBarTheme appBar(AppThemeExtension t, TextTheme text) => AppBarTheme(
    backgroundColor: t.background,
    foregroundColor: t.foreground,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: text.titleLarge,
  );

  /// Поле ввода: контур `input`, при фокусе — `primary`. `ring` (`#A1A1A1`) на
  /// белом даёт 2.6:1, меньше 3:1 для элементов, а `primary` инвертируется
  /// вместе с темой и остаётся контрастным.
  static InputDecorationTheme inputDecoration(
    AppThemeExtension t,
    TextTheme text,
  ) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      hintStyle: text.bodyMedium?.copyWith(color: t.mutedForeground),
      labelStyle: text.bodyMedium?.copyWith(color: t.mutedForeground),
      errorStyle: text.bodySmall?.copyWith(color: t.destructive),
      border: border(t.input),
      enabledBorder: border(t.input),
      disabledBorder: border(t.border),
      focusedBorder: border(t.primary, width: 1.5),
      errorBorder: border(t.destructive),
      focusedErrorBorder: border(t.destructive, width: 1.5),
    );
  }

  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
  );

  static FilledButtonThemeData filledButton() => FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: _buttonShape,
      minimumSize: const Size(64, _buttonHeight),
    ),
  );

  static OutlinedButtonThemeData outlinedButton() => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      shape: _buttonShape,
      minimumSize: const Size(64, _buttonHeight),
    ),
  );

  static TextButtonThemeData textButton() => TextButtonThemeData(
    style: TextButton.styleFrom(
      shape: _buttonShape,
      minimumSize: const Size(64, _buttonHeight),
    ),
  );

  /// Чип (выбор недели): выбранный — заливка `primary` и текст `primary-foreground`,
  /// невыбранный — прозрачный с границей `border`. Для `ChoiceChip` выбранный цвет
  /// и стиль подписи берутся из `secondary*`, поэтому заданы и они.
  static ChipThemeData chip(AppThemeExtension t, TextTheme text) {
    final label = text.bodyMedium?.copyWith(color: t.foreground);

    return ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: t.primary,
      secondarySelectedColor: t.primary,
      disabledColor: t.muted,
      surfaceTintColor: Colors.transparent,
      side: BorderSide(color: t.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      showCheckmark: false,
      checkmarkColor: t.primaryForeground,
      labelStyle: label,
      secondaryLabelStyle: label?.copyWith(color: t.primaryForeground),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    );
  }

  static DialogThemeData dialog(AppThemeExtension t, TextTheme text) =>
      DialogThemeData(
        backgroundColor: t.popover,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: t.border),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: t.popoverForeground,
        ),
      );

  static BottomSheetThemeData bottomSheet(AppThemeExtension t) =>
      BottomSheetThemeData(
        backgroundColor: t.popover,
        modalBackgroundColor: t.popover,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
          side: BorderSide(color: t.border),
        ),
      );

  static ProgressIndicatorThemeData progress(AppThemeExtension t) =>
      ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.muted,
        circularTrackColor: Colors.transparent,
      );
}
