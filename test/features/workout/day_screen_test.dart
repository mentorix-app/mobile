import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/core/widgets/skeleton_box.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_exercise.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/screens/day_screen.dart';
import 'package:mentorix_app/features/workout/presentation/screens/program_screen.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/block_card.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/completed_status.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_app_bar.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_skeleton.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/expandable_text.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/no_program_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/rest_day_view.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

import '../../helpers/workout_app_harness.dart';
import '../../helpers/workout_builders.dart';
import '../../helpers/workout_fakes.dart';

void main() {
  late FakeWorkoutRepository repository;
  late WorkoutAppHarness app;

  setUp(() {
    repository = FakeWorkoutRepository()..programResult = stageProgram();
    app = WorkoutAppHarness(repository);
  });

  tearDown(() => app.dispose());

  String dayPath(String key) => RouteNames.workoutDayPath('aziz', key);

  Future<AppLocalizations> pumpDay(
    WidgetTester tester,
    String dayKey, {
    Locale locale = const Locale('en'),
    ThemeData? theme,
    Size size = const Size(402, 874),
    double textScale = 1,
    bool settle = true,
    TargetPlatform platform = TargetPlatform.android,
    bool fromProgram = false,
  }) => app.pump(
    tester,
    initialPath: dayPath(dayKey),
    locale: locale,
    theme: theme,
    size: size,
    textScale: textScale,
    settle: settle,
    platform: platform,
  );

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  /// Тренировочный день с одним групповым блоком.
  TrainerProgram withBlocks(List blocks, {Set<String> completed = const {}}) =>
      trainerProgram(
        [
          week(1, [trainingDay(1, key: 'k', blocks: blocks.cast())]),
        ],
        completed: completed,
      );

  group('состояния', () {
    testWidgets('загрузка: скелетон, не спиннер', (tester) async {
      repository.programGate = Completer<void>();

      await pumpDay(tester, 'day-1', settle: false);

      expect(find.byType(DaySkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      repository.programGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(DaySkeleton), findsNothing);
      expect(find.text('Back Squat'), findsOneWidget);
    });

    testWidgets('экран восстановлен системой: программа грузится прямо здесь', (
      tester,
    ) async {
      await pumpDay(tester, 'day-2');

      expect(repository.programCalls, 1);
      expect(find.text('Kettlebell Swing'), findsOneWidget);
    });

    testWidgets('ошибка загрузки: сообщение и «Повторить»', (tester) async {
      repository.programFailure = const WorkoutNetworkFailure();

      final l10n = await pumpDay(tester, 'day-1');

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text(l10n.errorNetwork), findsOneWidget);

      repository.programFailure = null;
      await tester.tap(find.text(l10n.retryAction));
      await tester.pumpAndSettle();

      expect(find.text('Back Squat'), findsOneWidget);
    });

    testWidgets('связи с тренером нет — без «Повторить»', (tester) async {
      repository.programFailure = const WorkoutNotLinkedFailure();

      final l10n = await pumpDay(tester, 'day-1');

      expect(find.text(l10n.retryAction), findsNothing);
      expect(find.text('You are no longer linked to this trainer.'), findsOneWidget);
    });

    testWidgets('программа не назначена', (tester) async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');

      await pumpDay(tester, 'day-1');

      expect(find.byType(NoProgramView), findsOneWidget);
    });

    testWidgets('дня с таким ключом нет: «Этого дня больше нет», без «Повторить»', (
      tester,
    ) async {
      final l10n = await pumpDay(tester, 'нет-такого');

      expect(find.text(l10n.errorWorkoutDayNotFound), findsOneWidget);
      expect(find.text(l10n.retryAction), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('день отдыха по ссылке: «Rest day» и пояснение', (tester) async {
      final l10n = await pumpDay(tester, 'day-3');

      expect(find.byType(RestDayView), findsOneWidget);
      expect(find.text(l10n.dayRest), findsOneWidget);
      expect(find.text(l10n.dayRestBody), findsOneWidget);
      expect(find.text('Week 1, day 3'), findsWidgets);
    });

    testWidgets('тренер поменял программу: после обновления дня больше нет', (
      tester,
    ) async {
      final l10n = await pumpDay(tester, 'day-1');
      expect(find.text('Back Squat'), findsOneWidget);

      repository.programResult = trainerProgram([
        week(1, [trainingDay(1, key: 'другой-ключ')]),
      ]);
      await pullToRefresh(tester);

      expect(find.text(l10n.errorWorkoutDayNotFound), findsOneWidget);
      expect(find.text('Back Squat'), findsNothing);
    });

    testWidgets('ошибка обновления: день остаётся, снекбар', (tester) async {
      final l10n = await pumpDay(tester, 'day-1');
      repository.programFailure = const WorkoutServerUnavailableFailure();

      await pullToRefresh(tester);

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text(l10n.errorServerUnavailable), findsOneWidget);
    });
  });

  group('шапка', () {
    testWidgets('«Week 1, day 1» в крупной шапке; русский — «Неделя 1, день 1»', (
      tester,
    ) async {
      await pumpDay(tester, 'day-1');
      expect(find.byType(LargeTitleSliverAppBar), findsOneWidget);
      expect(find.text('Week 1, day 1'), findsWidgets);
    });

    testWidgets('русская шапка', (tester) async {
      await pumpDay(tester, 'day-4', locale: const Locale('ru'));

      expect(find.text('Неделя 1, день 4'), findsWidgets);
    });
  });

  group('блоки и упражнения (тестовая программа stage)', () {
    testWidgets('день 1: одиночные упражнения без подписи и рамки, суперсет — карточкой', (
      tester,
    ) async {
      await pumpDay(tester, 'day-1');

      for (final name in ['Back Squat', 'Arnold Press']) {
        expect(find.text(name), findsOneWidget);
        expect(
          find.ancestor(of: find.text(name), matching: find.byType(Card)),
          findsNothing,
          reason: '$name — без рамки блока',
        );
      }
      for (final name in ['Bench Press', 'Barbell Row']) {
        expect(
          find.ancestor(of: find.text(name), matching: find.byType(BlockCard)),
          findsOneWidget,
          reason: '$name — внутри карточки суперсета',
        );
      }
      expect(find.byType(BlockCard), findsOneWidget);
      expect(find.text('Superset'), findsOneWidget);
      expect(find.text('Single'), findsNothing, reason: 'подписи типа у single нет');
    });

    testWidgets('день 1: подходы и повторы', (tester) async {
      await pumpDay(tester, 'day-1');

      expect(find.text('5 × 5'), findsOneWidget);
      expect(find.text('4 × 10'), findsOneWidget);
      expect(find.text('4 × 12'), findsOneWidget);
      // Arnold Press: sets=3, reps нет.
      expect(find.text('Sets: 3'), findsOneWidget);
      expect(find.text('Reps: 3'), findsNothing);
    });

    testWidgets('день 2: EMOM — «Rounds / minutes» вместо подходов', (tester) async {
      await pumpDay(tester, 'day-2');

      expect(find.text('EMOM'), findsOneWidget);
      expect(find.text('Rounds / minutes: 5'), findsNWidgets(2));
      expect(find.text('Reps: 15'), findsOneWidget);
      expect(find.text('Reps: 10'), findsOneWidget);
      expect(find.textContaining('Sets'), findsNothing);
      expect(find.textContaining('×'), findsNothing);
    });

    testWidgets('день 2 по-русски: «Раунды / минуты: 5»', (tester) async {
      await pumpDay(tester, 'day-2', locale: const Locale('ru'));

      expect(find.text('Раунды / минуты: 5'), findsNWidgets(2));
      expect(find.text('Повторы: 15'), findsOneWidget);
      expect(find.textContaining('Подходы'), findsNothing);
    });

    testWidgets('день 4: AMRAP — только повторы, sets нет', (tester) async {
      await pumpDay(tester, 'day-4');

      expect(find.text('AMRAP'), findsOneWidget);
      expect(find.text('Reps: 12'), findsOneWidget);
      expect(find.text('Reps: 8'), findsOneWidget);
      expect(find.textContaining('Sets'), findsNothing);
      expect(find.text('Assault Bike'), findsOneWidget);
      expect(find.text('Burpee Box Jump Over'), findsOneWidget);
    });

    testWidgets('плашка «×» читается как «Sets 5, reps 5»', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpDay(tester, 'day-1');

      expect(find.bySemanticsLabel(RegExp('Sets 5, reps 5')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Sets 4, reps 10')), findsOneWidget);

      handle.dispose();
    });
  });

  group('названия и инструкции', () {
    testWidgets('русский: exercise_name_ru, если оно заполнено', (tester) async {
      repository.programResult = withBlocks([
        block(
          BlockType.single,
          exercises: [
            const ProgramExercise(id: '1', name: 'Back Squat', nameRu: 'Приседания со штангой'),
            const ProgramExercise(id: '2', name: 'Plank'),
          ],
        ),
      ]);

      await pumpDay(tester, 'k', locale: const Locale('ru'));

      expect(find.text('Приседания со штангой'), findsOneWidget);
      expect(find.text('Back Squat'), findsNothing);
      expect(find.text('Plank'), findsOneWidget, reason: 'нет name_ru — основное название');
    });

    testWidgets('английский при заполненном name_ru остаётся на name', (tester) async {
      repository.programResult = withBlocks([
        block(
          BlockType.single,
          exercises: [const ProgramExercise(id: '1', name: 'Back Squat', nameRu: 'Приседания')],
        ),
      ]);

      await pumpDay(tester, 'k');

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Приседания'), findsNothing);
    });

    testWidgets('упражнение без названия — «Exercise» / «Упражнение»', (tester) async {
      repository.programResult = withBlocks([
        block(BlockType.single, exercises: [const ProgramExercise(id: '1', name: '')]),
      ]);

      await pumpDay(tester, 'k');
      expect(find.text('Exercise'), findsOneWidget);
    });

    testWidgets('инструкции упражнения и блока показываются, пустые — нет', (tester) async {
      repository.programResult = withBlocks([
        block(
          BlockType.superset,
          instruction: 'Без отдыха между упражнениями',
          exercises: [
            exercise('A', instruction: '80 кг, отдых 2 мин'),
            exercise('B'),
          ],
        ),
      ]);

      await pumpDay(tester, 'k');

      expect(find.text('Без отдыха между упражнениями'), findsOneWidget);
      expect(find.text('80 кг, отдых 2 мин'), findsOneWidget);
      expect(find.byType(ExpandableText), findsNWidgets(2), reason: 'пустые не рисуются');
    });

    testWidgets('инструкция вместо единиц: «Считаем калории, не повторы» рядом с повторами', (
      tester,
    ) async {
      repository.programResult = withBlocks([
        block(
          BlockType.amrap,
          exercises: [exercise('Assault Bike', reps: '15', instruction: 'Считаем калории, не повторы')],
        ),
      ]);

      await pumpDay(tester, 'k');

      expect(find.text('Reps: 15'), findsOneWidget);
      expect(find.text('Считаем калории, не повторы'), findsOneWidget);
    });

    testWidgets('у single есть инструкция блока — примечание под упражнением', (tester) async {
      repository.programResult = withBlocks([
        block(BlockType.single, instruction: 'Темп 3-1-1', exercises: [exercise('Squat')]),
      ]);

      await pumpDay(tester, 'k');

      expect(find.text('Темп 3-1-1'), findsOneWidget);
      expect(find.byType(BlockCard), findsNothing);
      final squatY = tester.getTopLeft(find.text('Squat')).dy;
      expect(tester.getTopLeft(find.text('Темп 3-1-1')).dy, greaterThan(squatY));
    });

    for (final entry in {'светлая': AppTheme.light, 'тёмная': AppTheme.dark}.entries) {
      testWidgets('${entry.key}: инструкция — muted-foreground, название — не она', (tester) async {
        repository.programResult = withBlocks([
          block(BlockType.single, exercises: [exercise('Squat', instruction: 'Темп 3-1-1')]),
        ]);
        await pumpDay(tester, 'k', theme: entry.value);
        final tokens = entry.value.extension<AppThemeExtension>()!;

        expect(tester.widget<Text>(find.text('Темп 3-1-1')).style?.color, tokens.mutedForeground);
        expect(tester.widget<Text>(find.text('Squat')).style?.color, isNot(tokens.mutedForeground));
      });
    }

    testWidgets('короткая инструкция без «Show more»', (tester) async {
      repository.programResult = withBlocks([
        block(BlockType.single, exercises: [exercise('A', instruction: 'Коротко')]),
      ]);

      final l10n = await pumpDay(tester, 'k');

      expect(find.text(l10n.showMoreAction), findsNothing);
    });

    testWidgets('инструкция в 5000 символов: свёрнута, «Show more» раскрывает', (tester) async {
      final long = List.generate(400, (i) => 'слово$i').join(' ');
      repository.programResult = withBlocks([
        block(BlockType.single, exercises: [exercise('A', instruction: long)]),
      ]);

      final l10n = await pumpDay(tester, 'k');

      Text instruction() => tester.widget<Text>(find.text(long));
      expect(instruction().maxLines, 6);
      expect(instruction().overflow, TextOverflow.ellipsis);
      expect(find.text(l10n.showMoreAction), findsOneWidget);

      await tester.tap(find.text(l10n.showMoreAction));
      await tester.pumpAndSettle();

      expect(instruction().maxLines, isNull);
      expect(find.text(l10n.showLessAction), findsOneWidget);
      expect(find.text(l10n.showMoreAction), findsNothing);

      // Раскрытый текст длиннее экрана: кнопка внизу, её нужно показать.
      await tester.ensureVisible(find.text(l10n.showLessAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.showLessAction));
      await tester.pumpAndSettle();

      expect(instruction().maxLines, 6);
    });

    testWidgets('ровно 5000 символов подряд (без пробелов) не ломает вёрстку', (tester) async {
      repository.programResult = withBlocks([
        block(
          BlockType.complex,
          instruction: 'я' * 5000,
          exercises: [exercise('A', instruction: 'ы' * 5000)],
        ),
      ]);

      await pumpDay(tester, 'k', size: const Size(320, 640), textScale: 2);

      expect(tester.takeException(), isNull);
    });
  });

  group('выполненность — по completed_days сервера', () {
    testWidgets('выполненный день: «Completed» в конце', (tester) async {
      repository.programResult = stageProgram(completed: {'day-1'});

      await pumpDay(tester, 'day-1');

      expect(find.byType(CompletedStatus), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('невыполненный день: статуса нет', (tester) async {
      await pumpDay(tester, 'day-1');

      expect(find.byType(CompletedStatus), findsNothing);
    });

    testWidgets('отметили в боте: после обновления появляется «Completed»', (tester) async {
      await pumpDay(tester, 'day-2');
      expect(find.byType(CompletedStatus), findsNothing);

      repository.programResult = stageProgram(completed: {'day-2'});
      await pullToRefresh(tester);

      expect(find.byType(CompletedStatus), findsOneWidget);
    });
  });

  group('навигация', () {
    testWidgets('нажатие на карточку дня открывает день, «назад» возвращает к программе', (
      tester,
    ) async {
      await app.pump(tester);
      expect(find.byType(ProgramScreen), findsOneWidget);

      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();

      expect(find.byType(DayScreen), findsOneWidget);
      expect(app.router.state.matchedLocation, dayPath('day-2'));
      expect(find.text('Kettlebell Swing'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(DayScreen), findsNothing);
      expect(find.byType(ProgramScreen), findsOneWidget);
    });

    testWidgets('день открыт по ссылке: «назад» ведёт к программе этого тренера', (
      tester,
    ) async {
      await pumpDay(tester, 'day-1');
      expect(app.router.canPop(), isFalse);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ProgramScreen), findsOneWidget);
      expect(app.router.state.matchedLocation, RouteNames.trainerProgramPath('aziz'));
    });

    testWidgets('программа и день делят один кубит: второй запрос не уходит', (
      tester,
    ) async {
      await app.pump(tester);
      await tester.tap(find.text('Day 1'));
      await tester.pumpAndSettle();

      expect(repository.programCalls, 1);
    });

    testWidgets('iOS: свайп назад от левого края возвращает к программе', (tester) async {
      await app.pump(tester, platform: TargetPlatform.iOS);
      await tester.tap(find.text('Day 1'));
      await tester.pumpAndSettle();
      expect(find.byType(DayScreen), findsOneWidget);

      await tester.dragFrom(const Offset(2, 400), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.byType(DayScreen), findsNothing);
      expect(find.byType(ProgramScreen), findsOneWidget);
    });

    testWidgets('Android: системная кнопка «назад»', (tester) async {
      await app.pump(tester);
      await tester.tap(find.text('Day 1'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(ProgramScreen), findsOneWidget);
    });

    testWidgets('обновление на экране дня видно и на экране программы', (tester) async {
      await app.pump(tester);
      await tester.tap(find.text('Day 1'));
      await tester.pumpAndSettle();

      repository.programResult = stageProgram(completed: {'day-1'});
      await pullToRefresh(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Completed 1 of 3'), findsOneWidget);
    });

    testWidgets('другой тренер в пути — свой кубит и свой запрос', (tester) async {
      await app.pump(tester, initialPath: RouteNames.workoutDayPath('first', 'day-1'));

      app.router.go(RouteNames.workoutDayPath('second', 'day-1'));
      await tester.pumpAndSettle();

      expect(repository.programTrainerIds, ['first', 'second']);
    });
  });

  group('pull-to-refresh', () {
    testWidgets('Android: RefreshIndicator под шапкой, запрос уходит', (tester) async {
      await pumpDay(tester, 'day-1');

      final indicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      expect(indicator.edgeOffset, kToolbarHeight);

      await pullToRefresh(tester);

      expect(repository.programCalls, 2);
    });

    testWidgets('iOS: родной индикатор, контент отъезжает, Future ждёт кубит', (tester) async {
      await pumpDay(tester, 'day-1', platform: TargetPlatform.iOS);
      expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false), findsOneWidget);
      final slivers = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).slivers;
      expect(slivers[0], isA<DayAppBar>());
      expect(slivers[1], isA<CupertinoSliverRefreshControl>());

      repository.programGate = Completer<void>();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.programCalls, 2);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      repository.programGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('день отдыха тоже обновляется', (tester) async {
      await pumpDay(tester, 'day-3');

      repository.programResult = stageProgram();
      await pullToRefresh(tester);

      expect(repository.programCalls, 2);
    });
  });

  group('вёрстка', () {
    for (final entry in {'светлая': AppTheme.light, 'тёмная': AppTheme.dark}.entries) {
      for (final locale in const [Locale('ru'), Locale('en')]) {
        testWidgets(
          '${entry.key}, ${locale.languageCode}: 320 px, шрифт ×2, длинные названия и 12 упражнений',
          (tester) async {
            repository.programResult = withBlocks([
              block(
                BlockType.single,
                exercises: [exercise('Очень длинное название упражнения ' * 30, sets: '3-6', reps: '5/4')],
              ),
              block(
                BlockType.skillWork,
                instruction: 'Длинная инструкция блока ' * 40,
                exercises: [
                  for (var i = 0; i < 12; i++)
                    exercise(
                      'Упражнение $i',
                      sets: '10',
                      reps: '8-12',
                      instruction: i.isEven ? 'Вес и отдых ' * 20 : '',
                    ),
                ],
              ),
              block(BlockType.emom, exercises: [exercise('Burpee', sets: '10', reps: '5/4')]),
            ]);

            await pumpDay(
              tester,
              'k',
              locale: locale,
              theme: entry.value,
              size: const Size(320, 640),
              textScale: 2,
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('скелетон дня при шрифте ×2 не переполняется', (tester) async {
      repository.programGate = Completer<void>();

      await pumpDay(tester, 'day-1', size: const Size(320, 480), textScale: 2, settle: false);

      expect(tester.takeException(), isNull);
    });

    testWidgets('левый край упражнений, карточки блока и заголовка — 16 px', (tester) async {
      await pumpDay(tester, 'day-1');

      expect(tester.getTopLeft(find.text('Back Squat')).dx, 16);
      expect(tester.getTopLeft(find.byType(BlockCard)).dx, 16);
      expect(tester.getTopRight(find.byType(BlockCard)).dx, 402 - 16);
    });
  });
}
