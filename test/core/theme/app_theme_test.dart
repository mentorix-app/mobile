import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_text_theme.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // google_fonts при построении темы обращается к биндингу.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('токены светлой темы совпадают с globals.css', () {
    late final AppThemeExtension t;
    setUpAll(() => t = AppTheme.light.extension<AppThemeExtension>()!);

    test('основные цвета', () {
      expect(t.background, const Color(0xFFFFFFFF));
      expect(t.foreground, const Color(0xFF0A0A0A));
      expect(t.primary, const Color(0xFF171717));
      expect(t.primaryForeground, const Color(0xFFFAFAFA));
      expect(t.secondary, const Color(0xFFF5F5F5));
      expect(t.mutedForeground, const Color(0xFF737373));
      expect(t.border, const Color(0xFFE5E5E5));
      expect(t.ring, const Color(0xFFA1A1A1));
      expect(t.destructive, const Color(0xFFE7000B));
    });

    test('цветовая схема Material берёт токены', () {
      final scheme = AppTheme.light.colorScheme;
      expect(scheme.primary, t.primary);
      expect(scheme.onPrimary, t.primaryForeground);
      expect(scheme.error, t.destructive);
      expect(AppTheme.light.scaffoldBackgroundColor, t.background);
    });
  });

  group('токены тёмной темы совпадают с globals.css', () {
    late final AppThemeExtension t;
    setUpAll(() => t = AppTheme.dark.extension<AppThemeExtension>()!);

    test('основные цвета', () {
      expect(t.background, const Color(0xFF0A0A0A));
      expect(t.foreground, const Color(0xFFFAFAFA));
      expect(t.card, const Color(0xFF171717));
      expect(t.primary, const Color(0xFFE5E5E5));
      expect(t.primaryForeground, const Color(0xFF171717));
      expect(t.secondary, const Color(0xFF262626));
      expect(t.mutedForeground, const Color(0xFFA1A1A1));
      expect(t.ring, const Color(0xFF737373));
      expect(t.destructive, const Color(0xFFFF6467));
    });

    test('border и input — белый с прозрачностью', () {
      expect(t.border, const Color.fromRGBO(255, 255, 255, 0.10));
      expect(t.input, const Color.fromRGBO(255, 255, 255, 0.15));
    });
  });

  group('контраст WCAG AA', () {
    for (final entry in {
      'светлая': AppThemeExtension.light,
      'тёмная': AppThemeExtension.dark,
    }.entries) {
      final t = entry.value;

      test('${entry.key}: текст ≥ 4.5:1', () {
        expect(_contrast(t.foreground, t.background), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(t.cardForeground, t.card),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(t.primaryForeground, t.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(t.mutedForeground, t.background),
          greaterThanOrEqualTo(4.5),
        );
        // onError в ColorScheme — это primaryForeground.
        expect(
          _contrast(t.primaryForeground, t.destructive),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  test('текстовая шкала — мобильная колонка globals.css', () {
    final text = AppTheme.light.textTheme;
    expect(text.headlineLarge?.fontSize, 24);
    expect(text.headlineMedium?.fontSize, 20);
    expect(text.headlineSmall?.fontSize, 18);
    expect(text.titleLarge?.fontSize, 16);
    expect(text.titleMedium?.fontSize, 15);
    expect(text.bodyLarge?.fontSize, 16);
    expect(text.bodyMedium?.fontSize, 16);
    expect(text.bodySmall?.fontSize, 13);
    expect(text.labelSmall?.fontSize, 12);
    expect(text.bodyMedium?.color, AppThemeExtension.light.foreground);
    expect(AppTextTheme.h1, 24);
  });

  test('радиусы и отступы', () {
    expect(
      [
        AppRadii.sm,
        AppRadii.md,
        AppRadii.lg,
        AppRadii.xl,
        AppRadii.xl2,
        AppRadii.xl3,
        AppRadii.xl4,
      ],
      [6, 8, 10, 14, 18, 22, 26],
    );
    expect(AppSpacing.contentHorizontal, 9);
    expect(AppSpacing.contentVertical, 8);
    expect(AppSpacing.headerHeight, 56);
  });
}
