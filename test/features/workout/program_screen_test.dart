import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/core/widgets/skeleton_box.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/screens/day_screen.dart';
import 'package:mentorix_app/features/workout/presentation/screens/program_screen.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_card.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/no_program_view.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/rest_day_card.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/week_selector.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

import '../../helpers/workout_app_harness.dart';
import '../../helpers/workout_builders.dart';
import '../../helpers/workout_fakes.dart';

void main() {
  late FakeWorkoutRepository repository;
  late WorkoutAppHarness app;
  late GoRouter router;

  setUp(() {
    repository = FakeWorkoutRepository()..programResult = stageProgram();
    app = WorkoutAppHarness(repository);
  });

  tearDown(() => app.dispose());

  /// Экран программы под тем же `ShellRoute`, что и в приложении: так проверяется
  /// и чтение `trainerId` из пути, и общий кубит.
  Future<AppLocalizations> pumpProgram(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeData? theme,
    Size size = const Size(402, 874),
    double textScale = 1,
    bool settle = true,
    TargetPlatform platform = TargetPlatform.android,
    String trainerId = 'aziz',
    bool fromHome = false,
  }) async {
    final l10n = await app.pump(
      tester,
      locale: locale,
      theme: theme,
      size: size,
      textScale: textScale,
      settle: settle,
      platform: platform,
      trainerId: trainerId,
      fromHome: fromHome,
    );
    router = app.router;
    return l10n;
  }

  /// Левый край виджета в логических пикселях.
  double left(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder.first).dx;

  /// Левые края всех совпадений (у крупного названия их два: развёрнутое и
  /// свёрнутое).
  List<double> leftEdges(Finder finder) => [
    for (final element in finder.evaluate())
      (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx,
  ];

  /// Корневой блок шапки: сама `LargeTitleSliverAppBar` — сливер, а не `RenderBox`.
  Finder appBarBox() => find
      .descendant(of: find.byType(LargeTitleSliverAppBar), matching: find.byType(DecoratedBox))
      .first;

  /// Жест «назад» с левого края: дальше половины экрана, иначе iOS его отменяет.
  Future<void> swipeBack(WidgetTester tester, {double y = 400}) async {
    await tester.dragFrom(Offset(2, y), const Offset(600, 0));
    await tester.pumpAndSettle();
  }

  /// Название программы в крупной шапке: развёрнутое и свёрнутое лежат в дереве
  /// вместе, поэтому ищем внутри `LargeTitleSliverAppBar`.
  Finder appBarTitle(String name) =>
      find.descendant(of: find.byType(LargeTitleSliverAppBar), matching: find.text(name));

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  /// Две недели: в первой тренировочные дни `a`, `b` и отдых, во второй — `c`.
  TrainerProgram twoWeeks({Set<String> completed = const {}}) => trainerProgram(
    [
      week(1, [trainingDay(1, key: 'a'), trainingDay(2, key: 'b'), restDay(3)]),
      week(2, [restDay(1), trainingDay(2, key: 'c')]),
    ],
    completed: completed,
  );

  group('состояния', () {
    testWidgets('загрузка: скелетон, не спиннер', (tester) async {
      repository.programGate = Completer<void>();

      await pumpProgram(tester, settle: false);

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(DayCard), findsNothing);

      repository.programGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.byType(DayCard), findsWidgets);
    });

    testWidgets('trainerId берётся из пути и уходит в запрос', (tester) async {
      await pumpProgram(tester, trainerId: 'trainer-42');

      expect(repository.programTrainerIds, ['trainer-42']);
    });

    testWidgets('другой тренер в пути — новый кубит и новый запрос', (tester) async {
      await pumpProgram(tester, trainerId: 'first');

      router.go(RouteNames.trainerProgramPath('second'));
      await tester.pumpAndSettle();

      expect(repository.programTrainerIds, ['first', 'second']);
    });

    testWidgets('программа не назначена: пояснение, не ошибка', (tester) async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');

      final l10n = await pumpProgram(tester);

      expect(find.byType(NoProgramView), findsOneWidget);
      expect(find.text(l10n.programNotAssignedTitle), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(DayCard), findsNothing);
    });

    testWidgets('ошибка загрузки: сообщение и «Повторить» грузит снова', (
      tester,
    ) async {
      repository.programFailure = const WorkoutNetworkFailure();

      final l10n = await pumpProgram(tester);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text(l10n.errorNetwork), findsOneWidget);

      repository.programFailure = null;
      await tester.tap(find.text(l10n.retryAction));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(DayCard), findsWidgets);
      expect(repository.programCalls, 2);
    });

    testWidgets('связи с тренером нет или он заблокировал — без «Повторить»', (
      tester,
    ) async {
      final cases = {
        const WorkoutNotLinkedFailure(): 'You are no longer linked to this trainer.',
        const WorkoutBlockedFailure():
            'Your trainer has restricted your access to the program.',
      };

      for (final entry in cases.entries) {
        repository.programFailure = entry.key;

        final l10n = await pumpProgram(tester);

        expect(find.text(entry.value), findsOneWidget);
        expect(find.text(l10n.retryAction), findsNothing);
      }
    });

    testWidgets('ошибка обновления: данные остаются, снекбар каждый раз', (
      tester,
    ) async {
      final l10n = await pumpProgram(tester);
      repository.programFailure = const WorkoutServerUnavailableFailure();

      await pullToRefresh(tester);

      expect(find.byType(DayCard), findsNWidgets(3));
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text(l10n.errorServerUnavailable), findsOneWidget);

      ScaffoldMessenger.of(tester.element(find.byType(ProgramScreen))).clearSnackBars();
      await tester.pumpAndSettle();
      await pullToRefresh(tester);

      expect(find.text(l10n.errorServerUnavailable), findsOneWidget);
      expect(find.byType(DayCard), findsNWidgets(3));
    });
  });

  group('неделя с тестовой программой stage', () {
    testWidgets('заголовок, тренер, прогресс, три тренировочных дня и четыре отдыха', (
      tester,
    ) async {
      final l10n = await pumpProgram(tester);

      expect(appBarTitle('Mentorix-app'), findsWidgets);
      expect(find.byType(LargeTitleSliverAppBar), findsOneWidget);
      expect(
        find.text(l10n.programTitle),
        findsNothing,
        reason: 'маленького «Program» над названием больше нет',
      );
      expect(find.text('Aziz Geidar'), findsOneWidget);
      expect(find.text('Completed 0 of 3'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.byType(WeekSelector), findsNothing, reason: 'неделя одна');
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(DayCard), findsNWidgets(3));
      expect(find.byType(RestDayCard), findsNWidgets(4));
    });

    testWidgets('подписи дней: число упражнений и типы групп, у single подписи нет', (
      tester,
    ) async {
      await pumpProgram(tester);

      // День 1: Back Squat (single) + Superset (2) + Arnold Press (single).
      expect(find.text('4 exercises · Superset'), findsOneWidget);
      expect(find.text('2 exercises · EMOM'), findsOneWidget);
      expect(find.text('2 exercises · AMRAP'), findsOneWidget);
      expect(find.text('Single'), findsNothing);
      expect(find.textContaining('Single'), findsNothing);
    });

    testWidgets('день отдыха: «Rest day», не нажимается, без галочки', (tester) async {
      final l10n = await pumpProgram(tester);

      expect(find.text('Day 3 · ${l10n.dayRest}'), findsOneWidget);
      expect(find.textContaining(l10n.dayRest), findsNWidgets(4));

      await tester.tap(find.text('Day 3 · ${l10n.dayRest}'));
      await tester.pumpAndSettle();

      expect(find.byType(ProgramScreen), findsOneWidget);
      expect(
        find.descendant(of: find.byType(RestDayCard), matching: find.byIcon(Icons.check_circle)),
        findsNothing,
      );
    });

    testWidgets('русский: названия, плюрали и «День отдыха»', (tester) async {
      repository.programResult = trainerProgram(
        stageProgram().weeks,
        nameRu: 'Mentorix-app (тест)',
      );

      await pumpProgram(tester, locale: const Locale('ru'));

      expect(appBarTitle('Mentorix-app (тест)'), findsWidgets);
      expect(find.text('Программа'), findsNothing);
      expect(find.text('Выполнено 0 из 3'), findsOneWidget);
      expect(find.text('Неделя 1'), findsOneWidget);
      expect(find.text('День 1'), findsOneWidget);
      expect(find.text('4 упражнения · Суперсет'), findsOneWidget);
      expect(find.text('2 упражнения · EMOM'), findsOneWidget);
      expect(find.textContaining('День отдыха'), findsNWidgets(4));
      expect(find.text('День 3 · День отдыха'), findsOneWidget);
    });

    testWidgets('нет name_ru — в русском показывается основное название', (tester) async {
      await pumpProgram(tester, locale: const Locale('ru'));

      expect(appBarTitle('Mentorix-app'), findsWidgets);
    });

    testWidgets('английский при заполненном name_ru остаётся на name', (tester) async {
      repository.programResult = trainerProgram(
        stageProgram().weeks,
        nameRu: 'Название по-русски',
      );

      await pumpProgram(tester);

      expect(appBarTitle('Mentorix-app'), findsWidgets);
      expect(find.text('Название по-русски'), findsNothing);
    });

    testWidgets('пустое имя тренера — «Trainer»', (tester) async {
      repository.programResult = trainerProgram(stageProgram().weeks, trainerName: '');

      await pumpProgram(tester);

      expect(find.text('Trainer'), findsOneWidget);
    });

    testWidgets('неизвестный тип блока подписан «Block»', (tester) async {
      repository.programResult = trainerProgram([
        week(1, [
          trainingDay(1, blocks: [block(BlockType.unknown)]),
        ]),
      ]);

      await pumpProgram(tester);

      expect(find.text('1 exercise · Block'), findsOneWidget);
    });

    testWidgets('в неделе три дня — три карточки, а не семь', (tester) async {
      repository.programResult = trainerProgram([
        week(1, [trainingDay(1), restDay(2), trainingDay(3)]),
      ]);

      await pumpProgram(tester);

      expect(find.byType(DayCard), findsNWidgets(2));
      expect(find.byType(RestDayCard), findsOneWidget);
    });

    testWidgets('программа без тренировочных дней: прогресса и «пройдена» нет', (
      tester,
    ) async {
      repository.programResult = trainerProgram([week(1, [restDay(1), restDay(2)])]);

      final l10n = await pumpProgram(tester);

      expect(find.textContaining('Completed'), findsNothing);
      expect(find.text(l10n.programFinished), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(RestDayCard), findsNWidgets(2));
    });
  });

  group('выполненность — по completed_days сервера', () {
    testWidgets('отмеченный день: галочка и подпись «Completed», прогресс 1 из 3', (
      tester,
    ) async {
      repository.programResult = stageProgram(completed: {'day-1'});

      final l10n = await pumpProgram(tester);

      expect(find.text('Completed 1 of 3'), findsOneWidget);
      expect(find.text(l10n.dayCompleted), findsOneWidget);
      expect(
        find.descendant(of: find.byType(DayCard), matching: find.byIcon(Icons.check_circle)),
        findsOneWidget,
      );
      expect(find.text(l10n.programFinished), findsNothing);
    });

    testWidgets('чужой ключ и ключ дня отдыха ничего не отмечают', (tester) async {
      repository.programResult = stageProgram(completed: {'удалённый', 'day-3'});

      await pumpProgram(tester);

      expect(find.text('Completed 0 of 3'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('все тренировочные дни выполнены — «Программа пройдена»', (tester) async {
      repository.programResult = stageProgram(completed: {'day-1', 'day-2', 'day-4'});

      final l10n = await pumpProgram(tester);

      expect(find.text('Completed 3 of 3'), findsOneWidget);
      expect(find.text(l10n.programFinished), findsOneWidget);
      expect(find.byType(DayCard), findsNWidgets(3));
    });

    testWidgets('день, отмеченный в боте, получает галочку после обновления', (
      tester,
    ) async {
      await pumpProgram(tester);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      repository.programResult = stageProgram(completed: {'day-2'});
      await pullToRefresh(tester);

      expect(find.text('Completed 1 of 3'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('возврат в приложение тихо обновляет программу', (tester) async {
      await pumpProgram(tester);
      repository.programResult = stageProgram(completed: {'day-4'});

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.programCalls, 2);
      expect(find.text('Completed 1 of 3'), findsOneWidget);
    });

    testWidgets('возврат в приложение без связи: ни снекбара, ни потери данных', (
      tester,
    ) async {
      await pumpProgram(tester);
      repository.programFailure = const WorkoutNetworkFailure();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.programCalls, 2);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(DayCard), findsNWidgets(3));
    });

    testWidgets('другие состояния жизненного цикла запроса не шлют', (tester) async {
      await pumpProgram(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(repository.programCalls, 1);
    });

    testWidgets('после ухода с экрана подписка снята', (tester) async {
      await pumpProgram(tester);

      router.go(RouteNames.home);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.programCalls, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('несколько недель', () {
    testWidgets('чипы недель; стартовая — первая с невыполненным днём', (tester) async {
      repository.programResult = twoWeeks(completed: {'a', 'b'});

      await pumpProgram(tester);

      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Week 2'), findsOneWidget);
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.map((c) => c.selected), [false, true]);
      // На экране дни недели 2: «Day 1» — отдых, «Day 2» — тренировка.
      expect(find.byType(DayCard), findsOneWidget);
      expect(find.byType(RestDayCard), findsOneWidget);
    });

    testWidgets('ничего не выполнено — стартовая неделя 1', (tester) async {
      repository.programResult = twoWeeks();

      await pumpProgram(tester);

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.map((c) => c.selected), [true, false]);
      expect(find.byType(DayCard), findsNWidgets(2));
    });

    testWidgets('всё выполнено — открыта последняя неделя', (tester) async {
      repository.programResult = twoWeeks(completed: {'a', 'b', 'c'});

      await pumpProgram(tester);

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.map((c) => c.selected), [false, true]);
    });

    testWidgets('нажатие на чип переключает дни', (tester) async {
      repository.programResult = twoWeeks();
      await pumpProgram(tester);
      expect(find.byType(DayCard), findsNWidgets(2));

      await tester.tap(find.text('Week 2'));
      await tester.pumpAndSettle();

      expect(find.byType(DayCard), findsOneWidget);
      expect(find.byType(RestDayCard), findsOneWidget);
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.map((c) => c.selected), [false, true]);
    });

    testWidgets('выбор недели переживает обновление данных', (tester) async {
      repository.programResult = twoWeeks();
      await pumpProgram(tester);
      await tester.tap(find.text('Week 2'));
      await tester.pumpAndSettle();

      repository.programResult = twoWeeks(completed: {'a'});
      await pullToRefresh(tester);

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.map((c) => c.selected), [false, true]);
      expect(find.byType(DayCard), findsOneWidget);
    });

    testWidgets('выбранной недели больше нет — стартовая', (tester) async {
      repository.programResult = twoWeeks();
      await pumpProgram(tester);
      await tester.tap(find.text('Week 2'));
      await tester.pumpAndSettle();

      repository.programResult = trainerProgram([
        week(1, [trainingDay(1, key: 'a')]),
      ]);
      await pullToRefresh(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.byType(DayCard), findsOneWidget);
    });

    testWidgets('десять недель: чипы прокручиваются, ничего не переполняется', (
      tester,
    ) async {
      repository.programResult = trainerProgram([
        for (var n = 1; n <= 10; n++) week(n, [trainingDay(1, key: 'k$n')]),
      ]);

      await pumpProgram(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.byType(ChoiceChip, skipOffstage: false), findsNWidgets(10));
    });
  });

  group('pull-to-refresh', () {
    testWidgets('Android: RefreshIndicator, обновление идёт, индикатор ждёт кубит', (
      tester,
    ) async {
      await pumpProgram(tester);
      repository.programGate = Completer<void>();

      await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(repository.programCalls, 2);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      repository.programGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });

    testWidgets('iOS: CupertinoSliverRefreshControl, pull вызывает refresh', (tester) async {
      await pumpProgram(tester, platform: TargetPlatform.iOS);

      expect(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(RefreshIndicator), findsNothing);

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

    testWidgets('iOS, программа не назначена: pull обновляет и находит программу', (
      tester,
    ) async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');
      await pumpProgram(tester, platform: TargetPlatform.iOS);
      expect(find.byType(NoProgramView), findsOneWidget);

      repository.programResult = stageProgram();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(find.byType(NoProgramView), findsNothing);
      expect(find.byType(DayCard), findsNWidgets(3));
    });

    testWidgets('Android, программа не назначена: pull обновляет', (tester) async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');
      await pumpProgram(tester);

      repository.programResult = stageProgram();
      await pullToRefresh(tester);

      expect(find.byType(NoProgramView), findsNothing);
      expect(find.byType(DayCard), findsNWidgets(3));
    });
  });

  group('назад к списку тренеров', () {
    testWidgets('кнопка «назад» есть при загрузке', (tester) async {
      repository.programGate = Completer<void>();

      await pumpProgram(tester, fromHome: true, settle: false);

      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('кнопка «назад» есть при ошибке и без назначенной программы', (
      tester,
    ) async {
      repository.programFailure = const WorkoutNotLinkedFailure();
      await pumpProgram(tester, fromHome: true);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('кнопка «назад» есть, когда программы нет', (tester) async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');
      await pumpProgram(tester, fromHome: true);
      expect(find.byType(NoProgramView), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('кнопка «назад» есть у крупной шапки с программой', (tester) async {
      await pumpProgram(tester, fromHome: true);

      expect(find.byType(LargeTitleSliverAppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('$platform: нажатие на «назад» возвращает на список', (
        tester,
      ) async {
        await pumpProgram(tester, fromHome: true, platform: platform);
        expect(find.text('home-screen'), findsNothing);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('home-screen'), findsOneWidget);
        expect(find.byType(ProgramScreen), findsNothing);
      });
    }

    testWidgets('экран открыт по прямой ссылке: «назад» ведёт на главный', (
      tester,
    ) async {
      await pumpProgram(tester);
      expect(router.canPop(), isFalse);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('home-screen'), findsOneWidget);
    });

    testWidgets('Android: системная кнопка «назад»', (tester) async {
      await pumpProgram(tester, fromHome: true);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('home-screen'), findsOneWidget);
    });

    testWidgets('iOS: свайп от левого края возвращает на список', (tester) async {
      await pumpProgram(tester, fromHome: true, platform: TargetPlatform.iOS);

      await swipeBack(tester);

      expect(find.text('home-screen'), findsOneWidget);
      expect(find.byType(ProgramScreen), findsNothing);
    });

    testWidgets('iOS: свайп работает и поверх строки с чипами недель', (tester) async {
      repository.programResult = twoWeeks();
      await pumpProgram(tester, fromHome: true, platform: TargetPlatform.iOS);
      final chipRowY = tester.getCenter(find.byType(ChoiceChip).first).dy;

      await swipeBack(tester, y: chipRowY);

      expect(find.text('home-screen'), findsOneWidget);
    });

    for (final entry in {
      'загрузка': () => repository.programGate = Completer<void>(),
      'ошибка': () => repository.programFailure = const WorkoutNetworkFailure(),
      'программы нет': () =>
          repository.programResult = const TrainerProgram(trainerId: 'aziz'),
    }.entries) {
      testWidgets('iOS: свайп назад — ${entry.key}', (tester) async {
        entry.value();

        await pumpProgram(
          tester,
          fromHome: true,
          platform: TargetPlatform.iOS,
          settle: entry.key != 'загрузка',
        );
        // Жест включается, когда переход на экран закончился.
        await tester.pump(const Duration(seconds: 1));
        await tester.dragFrom(const Offset(2, 400), const Offset(600, 0));
        await tester.pumpAndSettle();

        expect(find.text('home-screen'), findsOneWidget);
      });
    }

    testWidgets('iOS: незавершённый жест не закрывает экран', (tester) async {
      await pumpProgram(tester, fromHome: true, platform: TargetPlatform.iOS);

      await tester.dragFrom(const Offset(2, 400), const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(find.byType(ProgramScreen), findsOneWidget);
    });

    testWidgets('повторный вход с тем же тренером открывает программу заново', (
      tester,
    ) async {
      await pumpProgram(tester, fromHome: true);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      router.push(RouteNames.trainerProgramPath('aziz'));
      await tester.pumpAndSettle();

      expect(find.byType(DayCard), findsNWidgets(3));
      expect(repository.programCalls, 2, reason: 'кубит закрыт и создан заново');
    });
  });

  group('одна сетка: левый край заголовков и карточек', () {
    const grid = 16.0;

    testWidgets('одна неделя: заголовок, тренер, прогресс и карточки на 16 px', (
      tester,
    ) async {
      await pumpProgram(tester);

      expect(
        leftEdges(appBarTitle('Mentorix-app')),
        contains(grid),
        reason: 'развёрнутое крупное название',
      );

      expect(left(tester, find.text('Aziz Geidar')), grid);
      expect(left(tester, find.text('Completed 0 of 3')), grid);
      expect(left(tester, find.byType(LinearProgressIndicator)), grid);
      expect(left(tester, find.text('Week 1')), grid);
      expect(left(tester, find.byType(DayCard)), grid);
      expect(left(tester, find.byType(RestDayCard)), grid);
    });

    testWidgets('несколько недель: первый чип тоже на 16 px', (tester) async {
      repository.programResult = twoWeeks();
      await pumpProgram(tester);

      expect(left(tester, find.byType(ChoiceChip)), grid);
      expect(left(tester, find.byType(DayCard)), grid);
      expect(left(tester, find.byType(RestDayCard)), grid);
    });

    testWidgets('правый край карточек симметричен: ширина экрана минус 16', (
      tester,
    ) async {
      await pumpProgram(tester);

      for (final type in [DayCard, RestDayCard]) {
        final rect = tester.getRect(find.byType(type).first);
        expect(rect.left, grid, reason: '$type');
        expect(rect.right, 402 - grid, reason: '$type');
      }
    });

    testWidgets('шрифт ×2 сетку не сдвигает', (tester) async {
      await pumpProgram(tester, textScale: 2);

      expect(left(tester, find.text('Week 1')), grid);
      // Список ленивый, при крупном шрифте карточки ниже экрана: докручиваем.
      await tester.dragUntilVisible(
        find.text('Day 1'),
        find.byType(CustomScrollView),
        const Offset(0, -100),
      );
      expect(
        left(tester, find.ancestor(of: find.text('Day 1'), matching: find.byType(DayCard))),
        grid,
      );

      await tester.dragUntilVisible(
        find.text('Day 7 · Rest day'),
        find.byType(CustomScrollView),
        const Offset(0, -100),
      );
      expect(
        left(tester, find.ancestor(of: find.text('Day 7 · Rest day'), matching: find.byType(RestDayCard))),
        grid,
      );
    });
  });

  group('день отдыха тише тренировочного', () {
    testWidgets('без заливки, только тонкая граница', (tester) async {
      await pumpProgram(tester);
      final tokens = AppTheme.light.extension<AppThemeExtension>()!;

      final card = tester.widget<Card>(
        find.descendant(of: find.byType(RestDayCard).first, matching: find.byType(Card)),
      );
      expect(card.color, Colors.transparent);

      final material = tester.widget<Material>(
        find.descendant(of: find.byType(RestDayCard).first, matching: find.byType(Material)).first,
      );
      expect(material.color, Colors.transparent);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.border);
      expect(shape.side.width, 1);
    });

    testWidgets('тренировочная карточка осталась с заливкой цвета card', (tester) async {
      await pumpProgram(tester);
      final tokens = AppTheme.light.extension<AppThemeExtension>()!;

      final material = tester.widget<Material>(
        find.descendant(of: find.byType(DayCard).first, matching: find.byType(Material)).first,
      );

      expect(material.color, tokens.card);
    });

    testWidgets('компактнее: ниже тренировочной карточки и не выше 44 px', (tester) async {
      await pumpProgram(tester);

      final rest = tester.getSize(find.byType(RestDayCard).first).height;
      final training = tester.getSize(find.byType(DayCard).first).height;

      expect(rest, lessThanOrEqualTo(44));
      expect(rest, lessThan(training));
    });

    testWidgets('одна строка приглушённым цветом, значка и второй строки нет', (
      tester,
    ) async {
      await pumpProgram(tester);
      final tokens = AppTheme.light.extension<AppThemeExtension>()!;

      final text = tester.widget<Text>(find.text('Day 3 · Rest day'));

      expect(text.style?.color, tokens.mutedForeground);
      expect(
        find.descendant(of: find.byType(RestDayCard).first, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(find.text('Rest day'), findsNothing, reason: 'не отдельной строкой');
    });

    testWidgets('в тёмной теме то же: прозрачная карточка с границей', (tester) async {
      await pumpProgram(tester, theme: AppTheme.dark);
      final tokens = AppTheme.dark.extension<AppThemeExtension>()!;

      final material = tester.widget<Material>(
        find.descendant(of: find.byType(RestDayCard).first, matching: find.byType(Material)).first,
      );

      expect(material.color, Colors.transparent);
      expect((material.shape! as RoundedRectangleBorder).side.color, tokens.border);
    });

    testWidgets('при шрифте ×2 не переполняется', (tester) async {
      await pumpProgram(tester, size: const Size(320, 640), textScale: 2);

      // Список ленивый: докручиваем до первого дня отдыха.
      await tester.dragUntilVisible(
        find.byType(RestDayCard),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RestDayCard), findsWidgets);
    });
  });

  group('крупная шапка с названием', () {
    testWidgets('название в SliverAppBar.large, тренер и прогресс — ниже', (tester) async {
      await pumpProgram(tester);

      expect(appBarTitle('Mentorix-app'), findsWidgets);
      expect(
        tester.getTopLeft(find.text('Aziz Geidar')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(appBarBox()).dy - 1),
        reason: 'тренер под шапкой',
      );
      expect(
        tester.getTopLeft(find.text('Completed 0 of 3')).dy,
        greaterThan(tester.getTopLeft(find.text('Aziz Geidar')).dy),
      );
    });

    testWidgets('при прокрутке шапка сворачивается, название остаётся наверху', (
      tester,
    ) async {
      await pumpProgram(tester, size: const Size(402, 480));
      final expandedHeight = tester.getSize(appBarBox()).height;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final collapsedHeight = tester.getSize(appBarBox()).height;
      expect(collapsedHeight, lessThan(expandedHeight));
      expect(collapsedHeight, lessThanOrEqualTo(kToolbarHeight));
      final titleTops = [
        for (final element in appBarTitle('Mentorix-app').evaluate())
          (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
      ];
      expect(titleTops.any((y) => y < 100), isTrue, reason: 'свёрнутое название у верхнего края');
      expect(find.byType(BackButton), findsOneWidget, reason: 'кнопка остаётся при прокрутке');
    });

    testWidgets('до двух строк: очень длинное название не ломает шапку', (tester) async {
      repository.programResult = trainerProgram(
        stageProgram().weeks,
        name: 'Очень длинное название программы ' * 40,
      );

      await pumpProgram(tester, size: const Size(320, 640), textScale: 2);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Android: индикатор обновления опущен под шапку', (tester) async {
      await pumpProgram(tester);

      final indicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));

      expect(indicator.edgeOffset, kToolbarHeight);
    });

    testWidgets('iOS: индикатор обновления идёт сразу под шапкой', (tester) async {
      await pumpProgram(tester, platform: TargetPlatform.iOS);

      final slivers = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).slivers;

      expect(slivers[0], isA<LargeTitleSliverAppBar>());
      expect(slivers[1], isA<CupertinoSliverRefreshControl>());
    });

    testWidgets('iOS: pull вызывает refresh и при шапке, контент отъезжает', (tester) async {
      await pumpProgram(tester, platform: TargetPlatform.iOS);
      final before = tester.getTopLeft(find.byType(DayCard).first).dy;
      repository.programGate = Completer<void>();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.programCalls, 2);
      expect(tester.getTopLeft(find.byType(DayCard).first).dy, greaterThan(before));

      repository.programGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(DayCard).first).dy, before);
    });
  });

  group('переход в день и кнопка «Продолжить»', () {
    String dayPath(String key) => RouteNames.workoutDayPath('aziz', key);

    testWidgets('нажатие на тренировочный день открывает его', (tester) async {
      await pumpProgram(tester);

      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();

      expect(find.byType(DayScreen), findsOneWidget);
      expect(router.state.matchedLocation, dayPath('day-2'));
      expect(find.text('Week 1, day 2'), findsWidgets);
    });

    testWidgets('выполненный день тоже открывается (просмотр)', (tester) async {
      repository.programResult = stageProgram(completed: {'day-1'});
      await pumpProgram(tester);

      await tester.tap(find.text('Day 1'));
      await tester.pumpAndSettle();

      expect(find.byType(DayScreen), findsOneWidget);
    });

    testWidgets('у тренировочных карточек есть стрелка, у дней отдыха нет', (tester) async {
      await pumpProgram(tester);

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
      expect(
        find.descendant(of: find.byType(RestDayCard).first, matching: find.byIcon(Icons.chevron_right)),
        findsNothing,
      );
    });

    testWidgets('день отдыха не открывается', (tester) async {
      await pumpProgram(tester);

      await tester.tap(find.text('Day 3 · Rest day'));
      await tester.pumpAndSettle();

      expect(find.byType(DayScreen), findsNothing);
      expect(find.byType(ProgramScreen), findsOneWidget);
    });

    testWidgets('день без ключа не нажимается: адрес строится по day_key', (tester) async {
      repository.programResult = trainerProgram([
        week(1, [trainingDay(1, key: ''), trainingDay(2, key: 'k2')]),
      ]);
      await pumpProgram(tester);

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('Day 1'));
      await tester.pumpAndSettle();
      expect(find.byType(DayScreen), findsNothing);
    });

    testWidgets('«Continue: week 1, day 1» ведёт к первому невыполненному дню', (tester) async {
      final l10n = await pumpProgram(tester);

      expect(find.text(l10n.programContinueAction(1, 1)), findsOneWidget);
      expect(find.text('Continue: week 1, day 1'), findsOneWidget);

      await tester.tap(find.text('Continue: week 1, day 1'));
      await tester.pumpAndSettle();

      expect(find.byType(DayScreen), findsOneWidget);
      expect(router.state.matchedLocation, dayPath('day-1'));
    });

    testWidgets('по-русски: «Продолжить: неделя 1, день 1»', (tester) async {
      await pumpProgram(tester, locale: const Locale('ru'));

      expect(find.text('Продолжить: неделя 1, день 1'), findsOneWidget);
    });

    testWidgets('первый день выполнен — следующий невыполненный, дни отдыха пропущены', (
      tester,
    ) async {
      repository.programResult = stageProgram(completed: {'day-1', 'day-2'});

      await pumpProgram(tester);

      expect(find.text('Continue: week 1, day 4'), findsOneWidget);
    });

    testWidgets('дни можно делать в любом порядке: выполнен второй — подсказка про первый', (
      tester,
    ) async {
      repository.programResult = stageProgram(completed: {'day-2'});

      await pumpProgram(tester);

      expect(find.text('Continue: week 1, day 1'), findsOneWidget);
      // Но открыть можно любой день.
      await tester.tap(find.text('Day 4'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, dayPath('day-4'));
    });

    testWidgets('неделя 1 выполнена — подсказка про неделю 2', (tester) async {
      repository.programResult = twoWeeks(completed: {'a', 'b'});

      await pumpProgram(tester);

      expect(find.text('Continue: week 2, day 2'), findsOneWidget);
    });

    testWidgets('всё выполнено — кнопки нет, есть «Программа пройдена»', (tester) async {
      repository.programResult = stageProgram(completed: {'day-1', 'day-2', 'day-4'});

      final l10n = await pumpProgram(tester);

      expect(find.textContaining('Continue'), findsNothing);
      expect(find.text(l10n.programFinished), findsOneWidget);
    });

    testWidgets('программа без тренировочных дней — кнопки нет', (tester) async {
      repository.programResult = trainerProgram([week(1, [restDay(1)])]);

      await pumpProgram(tester);

      expect(find.textContaining('Continue'), findsNothing);
    });

    testWidgets('следующий день без ключа — кнопки нет', (tester) async {
      repository.programResult = trainerProgram([
        week(1, [trainingDay(1, key: ''), trainingDay(2, key: 'k2')]),
      ]);

      await pumpProgram(tester);

      expect(find.textContaining('Continue'), findsNothing);
    });

    testWidgets('кнопка на всю ширину и на сетке 16 px', (tester) async {
      await pumpProgram(tester);

      final rect = tester.getRect(find.byType(FilledButton));

      expect(rect.left, 16);
      expect(rect.right, 402 - 16);
      expect(rect.height, greaterThanOrEqualTo(48));
    });

    testWidgets('после отметки дня в боте подсказка сдвигается', (tester) async {
      await pumpProgram(tester);
      expect(find.text('Continue: week 1, day 1'), findsOneWidget);

      repository.programResult = stageProgram(completed: {'day-1'});
      await pullToRefresh(tester);

      expect(find.text('Continue: week 1, day 2'), findsOneWidget);
    });

    testWidgets('кнопка не переполняется при ×2 и узком экране', (tester) async {
      await pumpProgram(tester, size: const Size(320, 640), textScale: 2, locale: const Locale('ru'));

      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('вёрстка', () {
    for (final entry in {'светлая': AppTheme.light, 'тёмная': AppTheme.dark}.entries) {
      for (final locale in const [Locale('ru'), Locale('en')]) {
        testWidgets(
          '${entry.key}, ${locale.languageCode}: 320 px, шрифт ×2, длинные названия',
          (tester) async {
            repository.programResult = trainerProgram(
              [
                week(1, [
                  trainingDay(
                    1,
                    key: 'k',
                    blocks: [
                      block(BlockType.skillWork),
                      block(BlockType.conditioning),
                      block(BlockType.weightlifting),
                    ],
                  ),
                  restDay(2),
                ]),
                week(2, [trainingDay(1, key: 'k2')]),
              ],
              name: 'Очень длинное название программы ' * 30,
              trainerName: 'Очень длинное имя тренера ' * 10,
              completed: {'k'},
            );

            await pumpProgram(
              tester,
              locale: locale,
              theme: entry.value,
              size: const Size(320, 640),
              textScale: 2,
            );

            expect(tester.takeException(), isNull);
            expect(find.byType(DayCard, skipOffstage: false), findsWidgets);
          },
        );
      }
    }

    testWidgets('скелетон при шрифте ×2 не переполняется', (tester) async {
      repository.programGate = Completer<void>();

      await pumpProgram(
        tester,
        size: const Size(320, 480),
        textScale: 2,
        settle: false,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('пустое состояние и ошибка при шрифте ×2', (tester) async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');
      await pumpProgram(tester, size: const Size(320, 480), textScale: 2);
      expect(tester.takeException(), isNull);

      repository.programFailure = const WorkoutNetworkFailure();
      await pumpProgram(tester, size: const Size(320, 480), textScale: 2, trainerId: 'x');
      expect(tester.takeException(), isNull);
    });
  });
}
