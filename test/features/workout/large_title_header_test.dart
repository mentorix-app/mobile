import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_text_theme.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';

import '../../helpers/workout_app_harness.dart';
import '../../helpers/workout_builders.dart';
import '../../helpers/workout_fakes.dart';

/// Крупная шапка экранов программы и дня, как large title в iOS.
void main() {
  late FakeWorkoutRepository repository;
  late WorkoutAppHarness app;

  // В тестах по умолчанию шрифт Ahem: каждый символ — квадрат размером с кегль, и
  // «Mentorix-app» в 34 sp переносится на две строки. Геометрию шапки меряем на
  // настоящем Inter, как на устройстве.
  setUpAll(() async {
    final loader = FontLoader('Inter');
    for (final file in ['Regular', 'Medium', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter_18pt-$file.ttf'));
    }
    await loader.load();
  });

  setUp(() {
    repository = FakeWorkoutRepository()..programResult = stageProgram();
    app = WorkoutAppHarness(repository);
  });

  tearDown(() => app.dispose());

  /// Тексты названия в шапке: [развёрнутое, свёрнутое] — в таком порядке они лежат
  /// в дереве.
  List<Text> titles(WidgetTester tester, String name) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(LargeTitleSliverAppBar),
          matching: find.text(name),
        ),
      )
      .toList();

  Finder titleFinder(String name, {required bool expanded}) {
    final all = find.descendant(
      of: find.byType(LargeTitleSliverAppBar),
      matching: find.text(name),
    );
    return expanded ? all.first : all.last;
  }

  Finder header() => find
      .descendant(
        of: find.byType(LargeTitleSliverAppBar),
        matching: find.byType(DecoratedBox),
      )
      .first;

  double opacityOf(WidgetTester tester, Finder text) => tester
      .widget<Opacity>(find.ancestor(of: text, matching: find.byType(Opacity)).first)
      .opacity;

  Future<void> pumpProgram(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1,
    Locale locale = const Locale('en'),
    ThemeData? theme,
  }) => app.pump(
    tester,
    size: size,
    textScale: textScale,
    locale: locale,
    theme: theme,
  );

  group('развёрнутая шапка', () {
    testWidgets('заголовок крупный и жирный — стиль из textTheme, не литерал', (tester) async {
      await pumpProgram(tester);

      final expanded = titles(tester, 'Mentorix-app').first;
      final themeStyle = AppTheme.light.textTheme.displaySmall!;

      // Тема приложения локализуется Material (`inherit` меняется), поэтому
      // сравниваем существенные поля, а не весь объект.
      expect(expanded.style!.fontSize, themeStyle.fontSize);
      expect(expanded.style!.fontWeight, themeStyle.fontWeight);
      expect(expanded.style!.height, themeStyle.height);
      expect(expanded.style!.fontFamily, themeStyle.fontFamily);
      expect(expanded.style!.fontSize, AppTextTheme.largeTitle);
      expect(expanded.style!.fontSize, 34);
      expect(expanded.style!.fontWeight, FontWeight.w700);
      expect(expanded.style!.color, AppThemeExtension.light.foreground);
      expect(expanded.maxLines, 2);
      expect(expanded.overflow, TextOverflow.ellipsis);
    });

    testWidgets('тёмная тема: тот же стиль, цвет foreground тёмной темы', (tester) async {
      await pumpProgram(tester, theme: AppTheme.dark);

      final expanded = titles(tester, 'Mentorix-app').first;

      expect(expanded.style!.fontSize, 34);
      expect(expanded.style!.color, AppThemeExtension.dark.foreground);
    });

    testWidgets('заголовок слева по линии контента — 16 px', (tester) async {
      await pumpProgram(tester);

      expect(tester.getTopLeft(titleFinder('Mentorix-app', expanded: true)).dx, 16);
      expect(tester.getTopLeft(find.text('Aziz Geidar')).dx, 16);
    });

    testWidgets('заголовок прижат к низу шапки и начинается сразу под тулбаром', (tester) async {
      await pumpProgram(tester);

      final headerRect = tester.getRect(header());
      final title = tester.getRect(titleFinder('Mentorix-app', expanded: true));

      // Под тулбаром (56) сразу заголовок: пустоты между стрелкой и ним нет.
      expect(title.top, closeTo(kToolbarHeight, 0.5));
      // Снизу — отступ в 4 px, как задано делегатом.
      expect(headerRect.bottom - title.bottom, closeTo(4, 0.5));
    });

    testWidgets('высота развёрнутой шапки — тулбар + строка заголовка, а не 150 px', (tester) async {
      await pumpProgram(tester);

      final height = tester.getSize(header()).height;

      // 56 + 34 * 1.2 + 4 ≈ 101. Material large был 152.
      expect(height, closeTo(56 + 34 * 1.2 + 4, 1));
      expect(height, lessThan(110));
    });

    testWidgets('между стрелкой «назад» и заголовком нет пустоты', (tester) async {
      await pumpProgram(tester);

      final back = tester.getRect(find.byType(BackButton));
      final title = tester.getRect(titleFinder('Mentorix-app', expanded: true));

      expect(title.top - back.bottom, lessThan(8));
      expect(title.top, greaterThanOrEqualTo(back.bottom - 0.5));
    });

    testWidgets('от заголовка до имени тренера 4–8 px', (tester) async {
      await pumpProgram(tester);

      final title = tester.getRect(titleFinder('Mentorix-app', expanded: true));
      final trainerTop = tester.getTopLeft(find.text('Aziz Geidar')).dy;

      expect(trainerTop - title.bottom, inInclusiveRange(4, 8));
    });

    testWidgets('русское название: тот же размер и вес', (tester) async {
      repository.programResult = trainerProgram(
        stageProgram().weeks,
        nameRu: 'Мой тренировочный план',
      );

      await pumpProgram(tester, locale: const Locale('ru'));

      final expanded = titles(tester, 'Мой тренировочный план').first;
      expect(expanded.style!.fontSize, 34);
      expect(expanded.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('экран дня: та же шапка, тот же стиль, тот же отступ', (tester) async {
      await app.pump(tester, initialPath: RouteNames.workoutDayPath('aziz', 'day-1'));

      final expanded = titles(tester, 'Week 1, day 1').first;

      expect(find.byType(LargeTitleSliverAppBar), findsOneWidget);
      expect(expanded.style!.fontSize, AppTheme.light.textTheme.displaySmall!.fontSize);
      expect(expanded.style!.fontWeight, FontWeight.w700);
      expect(tester.getTopLeft(titleFinder('Week 1, day 1', expanded: true)).dx, 16);
      expect(tester.getSize(header()).height, closeTo(56 + 34 * 1.2 + 4, 1));
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('сворачивание при прокрутке', () {
    testWidgets('плавно: высота убывает, крупный гаснет, маленький проявляется', (tester) async {
      await pumpProgram(tester, size: const Size(402, 480));
      final heights = <double>[tester.getSize(header()).height];
      final large = <double>[opacityOf(tester, titleFinder('Mentorix-app', expanded: true))];
      final small = <double>[opacityOf(tester, titleFinder('Mentorix-app', expanded: false))];

      // Шаг больше порога касания (18 px): меньший жест — нажатие на карточку.
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -25));
        await tester.pump();
        heights.add(tester.getSize(header()).height);
        large.add(opacityOf(tester, titleFinder('Mentorix-app', expanded: true)));
        small.add(opacityOf(tester, titleFinder('Mentorix-app', expanded: false)));
      }

      expect(large.first, 1);
      expect(small.first, 0);
      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], lessThanOrEqualTo(heights[i - 1]), reason: 'шаг $i: высота');
        expect(large[i], lessThanOrEqualTo(large[i - 1]), reason: 'шаг $i: крупный');
        expect(small[i], greaterThanOrEqualTo(small[i - 1]), reason: 'шаг $i: маленький');
      }
      expect(heights.last, lessThan(heights.first));
      // В середине пути оба заголовка не видны одновременно целиком.
      for (var i = 0; i < large.length; i++) {
        expect(large[i] + small[i], lessThanOrEqualTo(1.01), reason: 'шаг $i');
      }
    });

    testWidgets('свёрнуто: высота тулбара, маленький заголовок, крупный погас', (tester) async {
      await pumpProgram(tester, size: const Size(402, 480));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.getSize(header()).height, kToolbarHeight);
      expect(opacityOf(tester, titleFinder('Mentorix-app', expanded: false)), 1);
      expect(opacityOf(tester, titleFinder('Mentorix-app', expanded: true)), 0);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('свёрнутый заголовок по центру шапки, одна строка, стиль AppBar', (tester) async {
      await pumpProgram(tester, size: const Size(402, 480));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      final collapsed = titles(tester, 'Mentorix-app').last;
      final center = tester.getCenter(titleFinder('Mentorix-app', expanded: false));

      expect(collapsed.maxLines, 1);
      expect(collapsed.overflow, TextOverflow.ellipsis);
      expect(collapsed.style!.fontSize, AppTheme.light.appBarTheme.titleTextStyle!.fontSize);
      expect(collapsed.style!.fontWeight, FontWeight.w600);
      expect(center.dx, closeTo(402 / 2, 1));
      expect(center.dy, closeTo(kToolbarHeight / 2, 2));
    });

    testWidgets('снизу свёрнутой шапки появляется тонкая линия', (tester) async {
      await pumpProgram(tester, size: const Size(402, 480));

      Color lineColor() {
        final box = tester.widget<DecoratedBox>(header());
        final border = (box.decoration as BoxDecoration).border! as Border;
        return border.bottom.color;
      }

      expect(lineColor().a, 0);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(lineColor().a, closeTo(AppThemeExtension.light.border.a, 0.01));
    });

    testWidgets('кнопка «назад» остаётся на месте при прокрутке', (tester) async {
      await pumpProgram(tester, size: const Size(402, 480));
      final before = tester.getTopLeft(find.byType(BackButton));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byType(BackButton)), before);
    });

    testWidgets('экран дня сворачивается так же', (tester) async {
      repository.programResult = trainerProgram([
        week(1, [
          trainingDay(
            1,
            key: 'k',
            blocks: [
              for (var i = 0; i < 20; i++)
                block(
                  BlockType.single,
                  exercises: [exercise('Упражнение $i', sets: '3', reps: '10', instruction: 'Вес и отдых')],
                ),
            ],
          ),
        ]),
      ]);

      await app.pump(
        tester,
        initialPath: RouteNames.workoutDayPath('aziz', 'k'),
        size: const Size(402, 480),
      );
      final expanded = tester.getSize(header()).height;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(tester.getSize(header()).height, kToolbarHeight);
      expect(expanded, greaterThan(kToolbarHeight));
    });
  });

  group('длинное название и крупный шрифт', () {
    // Больше 1000 символов; без хвостового пробела — название обрезается по краям.
    final longName = ('Очень длинное название программы тренировок ' * 25).trim();

    testWidgets('до 1000 символов: максимум две строки с многоточием в развёрнутом виде', (
      tester,
    ) async {
      repository.programResult = trainerProgram(stageProgram().weeks, name: longName);

      await pumpProgram(tester);

      final expanded = titles(tester, longName).first;
      final collapsed = titles(tester, longName).last;
      expect(longName.length, greaterThan(1000));
      expect(expanded.maxLines, 2);
      expect(expanded.overflow, TextOverflow.ellipsis);
      expect(collapsed.maxLines, 1);
      expect(collapsed.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('высота шапки: ровно две строки, не больше', (tester) async {
      repository.programResult = trainerProgram(stageProgram().weeks, name: longName);

      await pumpProgram(tester);

      final height = tester.getSize(header()).height;
      final titleBox = tester.getSize(titleFinder(longName, expanded: true)).height;

      expect(height, closeTo(56 + 2 * 34 * 1.2 + 4, 1));
      expect(titleBox, closeTo(2 * 34 * 1.2, 1));
    });

    testWidgets('длинное название: контент начинается сразу под шапкой', (tester) async {
      repository.programResult = trainerProgram(stageProgram().weeks, name: longName);

      await pumpProgram(tester);

      final headerBottom = tester.getRect(header()).bottom;
      final trainerTop = tester.getTopLeft(find.text('Aziz Geidar')).dy;
      expect(trainerTop - headerBottom, closeTo(4, 0.5));
    });

    for (final entry in {'светлая': AppTheme.light, 'тёмная': AppTheme.dark}.entries) {
      for (final locale in const [Locale('ru'), Locale('en')]) {
        testWidgets('${entry.key}, ${locale.languageCode}: 320 px, шрифт ×2, название 1000+ символов', (
          tester,
        ) async {
          repository.programResult = trainerProgram(stageProgram().weeks, name: longName);

          await pumpProgram(
            tester,
            size: const Size(320, 640),
            textScale: 2,
            locale: locale,
            theme: entry.value,
          );

          expect(tester.takeException(), isNull);
          final height = tester.getSize(header()).height;
          // Две строки крупного заголовка при ×2: 56 + 2 * 34 * 1.2 * 2 + 4.
          expect(height, closeTo(56 + 2 * 34 * 1.2 * 2 + 4, 2));
          expect(tester.getTopLeft(titleFinder(longName, expanded: true)).dx, 16);
          // Шапка не съедает весь экран.
          expect(height, lessThan(640 * 0.4));
        });
      }
    }

    testWidgets('шрифт ×2, короткое название: одна строка, высота растёт вместе со шрифтом', (
      tester,
    ) async {
      repository.programResult = trainerProgram(stageProgram().weeks, name: 'Plan');
      await pumpProgram(tester, size: const Size(402, 874), textScale: 2);

      final height = tester.getSize(header()).height;

      expect(height, closeTo(56 + 34 * 1.2 * 2 + 4, 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('свёрнутая шапка при ×2 остаётся высотой в тулбар', (tester) async {
      repository.programResult = trainerProgram(stageProgram().weeks, name: longName);
      await pumpProgram(tester, size: const Size(320, 480), textScale: 2);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(tester.getSize(header()).height, kToolbarHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('экран дня: название дня и длинное название блока при ×2', (tester) async {
      await app.pump(
        tester,
        initialPath: RouteNames.workoutDayPath('aziz', 'day-1'),
        size: const Size(320, 640),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(titleFinder('Week 1, day 1', expanded: true)).dx, 16);
    });
  });
}
