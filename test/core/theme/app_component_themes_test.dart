import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
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

double? _radius(ShapeBorder? shape) {
  final radius = (shape as RoundedRectangleBorder?)?.borderRadius;
  return (radius as BorderRadius?)?.topLeft.x;
}

void main() {
  final themes = {'светлая': AppTheme.light, 'тёмная': AppTheme.dark};

  for (final entry in themes.entries) {
    final theme = entry.value;
    final t = theme.extension<AppThemeExtension>()!;

    group('тема компонентов, ${entry.key}', () {
      test('шрифт Inter задан в ThemeData и во всей текстовой шкале', () {
        // ThemeData не хранит fontFamily, но применяет его к обеим шкалам.
        expect(theme.primaryTextTheme.bodyMedium?.fontFamily, 'Inter');
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
        expect(theme.textTheme.headlineLarge?.fontFamily, 'Inter');
        expect(theme.textTheme.labelLarge?.fontFamily, 'Inter');
        expect(AppTextTheme.fontFamily, 'Inter');
      });

      test('AppBar: плоский, цвета фона и текста из токенов', () {
        final bar = theme.appBarTheme;
        expect(bar.backgroundColor, t.background);
        expect(bar.foregroundColor, t.foreground);
        expect(bar.elevation, 0);
        expect(bar.scrolledUnderElevation, 0);
        expect(bar.surfaceTintColor, Colors.transparent);
        expect(bar.titleTextStyle?.fontSize, AppTextTheme.h4);
      });

      test('крупный заголовок экрана: displaySmall — 34 sp, w700, из текстовой шкалы', () {
        final style = theme.textTheme.displaySmall!;

        expect(style.fontSize, AppTextTheme.largeTitle);
        expect(style.fontSize, 34);
        expect(style.fontWeight, FontWeight.w700);
        expect(style.fontFamily, 'Inter');
        expect(style.height, 1.2);
        expect(style.color, t.foreground);
      });

      test('карточка без внешнего отступа: левый край задаёт список', () {
        expect(theme.cardTheme.margin, EdgeInsets.zero);
      });

      test('поле ввода: радиус 10, контур input, фокус primary', () {
        final input = theme.inputDecorationTheme;
        final enabled = input.enabledBorder! as OutlineInputBorder;
        final focused = input.focusedBorder! as OutlineInputBorder;
        final error = input.errorBorder! as OutlineInputBorder;

        expect(enabled.borderRadius, BorderRadius.circular(AppRadii.lg));
        expect(enabled.borderSide.color, t.input);
        expect(focused.borderSide.color, t.primary);
        expect(error.borderSide.color, t.destructive);
        expect(input.hintStyle?.color, t.mutedForeground);
      });

      test('кнопки: радиус 8 и высота не меньше 48', () {
        for (final style in [
          theme.filledButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
        ]) {
          expect(_radius(style?.shape?.resolve({})), AppRadii.md);
          expect(style?.minimumSize?.resolve({})?.height, 48);
        }
      });

      test('диалог и шторка: popover, радиус 14, граница border', () {
        final dialog = theme.dialogTheme;
        expect(dialog.backgroundColor, t.popover);
        expect(_radius(dialog.shape), AppRadii.xl);
        expect(dialog.titleTextStyle?.fontSize, AppTextTheme.h3);

        final sheet = theme.bottomSheetTheme;
        expect(sheet.backgroundColor, t.popover);
        expect(sheet.modalBackgroundColor, t.popover);
        final top = (sheet.shape! as RoundedRectangleBorder).borderRadius;
        expect((top as BorderRadius).topLeft.x, AppRadii.xl);
        expect(top.bottomLeft.x, 0);
      });

      test('прогресс: заливка primary, трек muted', () {
        final progress = theme.progressIndicatorTheme;
        expect(progress.color, t.primary);
        expect(progress.linearTrackColor, t.muted);
      });

      test('цвета компонентов — только токены globals.css', () {
        final allowed = {
          t.background,
          t.foreground,
          t.card,
          t.popover,
          t.popoverForeground,
          t.primary,
          t.primaryForeground,
          t.muted,
          t.mutedForeground,
          t.border,
          t.input,
          t.destructive,
          Colors.transparent,
        };
        final chip = theme.chipTheme;
        final used = <Color?>[
          theme.appBarTheme.backgroundColor,
          theme.appBarTheme.foregroundColor,
          theme.dialogTheme.backgroundColor,
          theme.bottomSheetTheme.backgroundColor,
          theme.progressIndicatorTheme.color,
          theme.progressIndicatorTheme.linearTrackColor,
          chip.backgroundColor,
          chip.selectedColor,
          chip.secondarySelectedColor,
          chip.disabledColor,
          chip.side?.color,
          chip.labelStyle?.color,
          chip.secondaryLabelStyle?.color,
          chip.checkmarkColor,
        ];
        for (final color in used) {
          expect(allowed, contains(color));
        }
      });

      test('«выполнено» — нейтральная галочка: primary контрастен к фону и карточке', () {
        expect(_contrast(t.primary, t.background), greaterThanOrEqualTo(3));
        expect(_contrast(t.primary, t.card), greaterThanOrEqualTo(3));
      });

      test('граница поля при фокусе контрастна к фону (≥ 3:1)', () {
        final focused =
            theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
        expect(
          _contrast(focused.borderSide.color, t.background),
          greaterThanOrEqualTo(3),
        );
      });

      testWidgets('ChoiceChip: выбранный залит primary, подпись primary-foreground',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Выбран'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                  ChoiceChip(
                    label: const Text('Не выбран'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        RawChip rawChip(String label) => tester.widget<RawChip>(
          find.descendant(
            of: find.ancestor(
              of: find.text(label),
              matching: find.byType(ChoiceChip),
            ),
            matching: find.byType(RawChip),
          ),
        );

        Color? labelColor(String label) =>
            DefaultTextStyle.of(tester.element(find.text(label))).style.color;

        // Цвет заливки выбранного ChoiceChip берётся из secondarySelectedColor.
        expect(rawChip('Выбран').selectedColor, t.primary);
        expect(rawChip('Выбран').selected, isTrue);
        expect(labelColor('Выбран'), t.primaryForeground);
        expect(rawChip('Не выбран').selected, isFalse);
        expect(labelColor('Не выбран'), t.foreground);
        expect(
          _contrast(t.primaryForeground, t.primary),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }
}
