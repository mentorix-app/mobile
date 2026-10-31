import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/core/widgets/skeleton_box.dart';
import 'package:mentorix_app/features/workout/data/models/client_analytics_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_record.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_comment.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/completion_time_format.dart';
import 'package:mentorix_app/features/workout/presentation/screens/day_screen.dart';
import 'package:mentorix_app/features/workout/presentation/screens/program_screen.dart';
import 'package:mentorix_app/features/workout/presentation/screens/stats_screen.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/completion_tile.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/result_bubble.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/stats_skeleton.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/trainer_reply_bubble.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

import '../../helpers/stats_fakes.dart';
import '../../helpers/workout_app_harness.dart';
import '../../helpers/workout_builders.dart';
import '../../helpers/workout_fakes.dart';

void main() {
  late FakeWorkoutRepository repository;
  late FakeStatsRepository stats;
  late WorkoutAppHarness app;

  ClientAnalytics sample([String name = 'client_analytics.json']) =>
      ClientAnalyticsModel.fromJson(loadAnalyticsSample(name));

  setUp(() {
    repository = FakeWorkoutRepository()..programResult = stageProgram();
    stats = FakeStatsRepository()..result = sample();
    app = WorkoutAppHarness(repository, stats: stats);
  });

  tearDown(() => app.dispose());

  Future<AppLocalizations> pumpStats(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeData? theme,
    Size size = const Size(402, 874),
    double textScale = 1,
    bool settle = true,
    TargetPlatform platform = TargetPlatform.android,
    bool fromProgram = false,
  }) => app.pump(
    tester,
    initialPath: RouteNames.statsPath('aziz'),
    locale: locale,
    theme: theme,
    size: size,
    textScale: textScale,
    settle: settle,
    platform: platform,
    fromHome: fromProgram,
  );

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  CompletionRecord record(
    int index, {
    String result = 'Сделал',
    List<TrainerComment> comments = const [],
    String program = 'Mentorix-app',
    String programRu = '',
  }) => CompletionRecord(
    id: 'r$index',
    completedAt: DateTime.utc(2026, 10, 28, 12, index),
    programName: program,
    programNameRu: programRu,
    weekNumber: 1,
    dayNumber: index,
    resultText: result,
    comments: comments,
  );

  ClientAnalytics withRecords(
    List<CompletionRecord> records, {
    ClientActivity activity = const ClientActivity(totalCompletions: 1),
    AssignmentProgress? assignment,
  }) => ClientAnalytics(
    currentAssignment: assignment,
    activity: activity,
    recentCompletions: records,
  );

  group('состояния', () {
    testWidgets('загрузка: скелетон, не спиннер', (tester) async {
      stats.gate = Completer<void>();

      await pumpStats(tester, settle: false);

      expect(find.byType(StatsSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      stats.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(StatsSkeleton), findsNothing);
      expect(find.byType(CompletionTile), findsWidgets);
    });

    testWidgets('запрос идёт по trainerId из адреса', (tester) async {
      await app.pump(tester, initialPath: RouteNames.statsPath('trainer-42'));

      expect(stats.trainerIds, ['trainer-42']);
    });

    testWidgets('ошибка: сообщение и «Повторить»', (tester) async {
      stats.failure = const WorkoutNetworkFailure();

      final l10n = await pumpStats(tester);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text(l10n.errorNetwork), findsOneWidget);

      stats.failure = null;
      await tester.tap(find.text(l10n.retryAction));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(CompletionTile), findsWidgets);
    });

    testWidgets('связи с тренером нет (404 client_not_found) — без «Повторить»', (tester) async {
      stats.failure = const WorkoutNotLinkedFailure();

      final l10n = await pumpStats(tester);

      expect(find.text('You are no longer linked to this trainer.'), findsOneWidget);
      expect(find.text(l10n.retryAction), findsNothing);
    });

    testWidgets('ошибка обновления: данные остаются, уведомление каждый раз', (tester) async {
      final l10n = await pumpStats(tester);
      stats.failure = const WorkoutServerUnavailableFailure();

      await pullToRefresh(tester);

      expect(find.byType(CompletionTile), findsNWidgets(2));
      expect(find.text(l10n.errorServerUnavailable), findsOneWidget);

      ScaffoldMessenger.of(tester.element(find.byType(StatsScreen))).clearSnackBars();
      await tester.pumpAndSettle();
      await pullToRefresh(tester);

      expect(find.text(l10n.errorServerUnavailable), findsOneWidget);
    });
  });

  group('образец: две отметки, на одной ответ тренера', () {
    testWidgets('заголовки разделов', (tester) async {
      final l10n = await pumpStats(tester);

      expect(find.text(l10n.statsTitle), findsWidgets);
      expect(find.text('Current program'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Workout results'), findsOneWidget);
    });

    testWidgets('по-русски: «Текущая программа», «Результаты тренировок», «Ответ тренера»', (
      tester,
    ) async {
      await pumpStats(tester, locale: const Locale('ru'));

      expect(find.text('Текущая программа'), findsOneWidget);
      expect(find.text('Результаты тренировок'), findsOneWidget);
      expect(find.text('Ответ тренера'), findsOneWidget);
      expect(find.text('Статистика'), findsWidgets);
    });

    testWidgets('текущая программа: название, 2 из 3, 66.7 %', (tester) async {
      await pumpStats(tester);

      expect(find.text('Mentorix-app'), findsOneWidget);
      expect(find.text('Completed 2 of 3'), findsOneWidget);
      expect(find.text('66.7%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(0.667, 0.001));
    });

    testWidgets('по-русски: название программы name_ru, процент с запятой', (tester) async {
      await pumpStats(tester, locale: const Locale('ru'));

      expect(find.text('Mentorix-app (тест)'), findsOneWidget);
      expect(find.text('Выполнено 2 из 3'), findsOneWidget);
      expect(find.text('66,7%'), findsOneWidget);
    });

    testWidgets('активность: всего, 7 и 30 дней, серия недель', (tester) async {
      final l10n = await pumpStats(tester);

      for (final label in [l10n.statsTotal, l10n.statsLast7Days, l10n.statsLast30Days, l10n.statsWeekStreak]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Всего 2, за 7 дней 2, за 30 дней 2, серия 1.
      expect(find.text('2'), findsNWidgets(3));
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('одна неделя — разбивки по неделям нет', (tester) async {
      await pumpStats(tester);

      expect(find.textContaining('Week 1:'), findsNothing);
    });

    testWidgets('записи: новые сверху, «Week N, day M» — снимок отметки', (tester) async {
      await pumpStats(tester);

      final newer = tester.getTopLeft(find.text('Week 1, day 2')).dy;
      final older = tester.getTopLeft(find.text('Week 1, day 1')).dy;
      expect(newer, lessThan(older));
    });

    testWidgets('время отметки — в часовом поясе устройства, по языку приложения', (tester) async {
      await pumpStats(tester);

      expect(
        find.text(formatCompletionTime(DateTime.utc(2026, 10, 28, 16, 33, 4), 'en')),
        findsOneWidget,
      );
      expect(
        find.text(formatCompletionTime(DateTime.utc(2026, 10, 28, 16, 31, 18), 'en')),
        findsOneWidget,
      );
    });

    testWidgets('результат клиента — в пузыре, у каждой записи', (tester) async {
      await pumpStats(tester);

      expect(find.byType(ResultBubble), findsNWidgets(2));
      expect(find.text('Kkk'), findsOneWidget);
      expect(find.text('Sssss'), findsOneWidget);
    });

    testWidgets('«Ответ тренера» есть у первой записи и только у неё', (tester) async {
      await pumpStats(tester);

      expect(find.byType(TrainerReplyBubble), findsOneWidget);
      expect(find.text('Trainer reply'), findsOneWidget);
      expect(
        find.text('Хорошая работа! В следующий раз напиши, с каким весом делал свинги.'),
        findsOneWidget,
      );
      // Ответ лежит под своей записью (день 2), а не под днём 1.
      final reply = tester.getTopLeft(find.byType(TrainerReplyBubble)).dy;
      expect(reply, greaterThan(tester.getTopLeft(find.text('Week 1, day 2')).dy));
      expect(reply, lessThan(tester.getTopLeft(find.text('Week 1, day 1')).dy));
    });

    testWidgets('время ответа тренера показано', (tester) async {
      await pumpStats(tester);

      expect(
        find.text(formatCompletionTime(DateTime.utc(2026, 10, 29, 13, 28, 2), 'en')),
        findsOneWidget,
      );
    });

    testWidgets('бейджа «Текущий цикл» клиенту нет, статусов проверки нет', (tester) async {
      await pumpStats(tester);
      expect(find.textContaining('cycle', findRichText: true), findsNothing);
      expect(find.textContaining('Needs attention'), findsNothing);
      expect(find.textContaining('Reviewed'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await app.dispose();
      app = WorkoutAppHarness(repository, stats: stats);
      await pumpStats(tester, locale: const Locale('ru'));
      expect(find.textContaining('цикл'), findsNothing);
      expect(find.textContaining('Требует внимания'), findsNothing);
      expect(find.textContaining('Проверено'), findsNothing);
    });

    testWidgets('ответить тренеру нельзя: ни поля ввода, ни кнопки «Отправить»', (tester) async {
      await pumpStats(tester);

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('нет подписи программы под записью, пока программа одна', (tester) async {
      await pumpStats(tester);

      // «Mentorix-app» только в карточке текущей программы.
      expect(find.text('Mentorix-app'), findsOneWidget);
    });
  });

  group('образец до первой отметки', () {
    testWidgets('прогресс 0 из 3, активности нет, пояснение вместо списка', (tester) async {
      stats.result = sample('client_analytics_empty.json');

      final l10n = await pumpStats(tester);

      expect(find.text('Completed 0 of 3'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text(l10n.statsActivity), findsNothing);
      expect(find.text(l10n.statsEmptyResults), findsOneWidget);
      expect(find.byType(CompletionTile), findsNothing);
    });

    testWidgets('по-русски: «Вы ещё не отмечали тренировки»', (tester) async {
      stats.result = sample('client_analytics_empty.json');

      await pumpStats(tester, locale: const Locale('ru'));

      expect(find.text('Вы ещё не отмечали тренировки'), findsOneWidget);
    });
  });

  group('содержимое записей', () {
    testWidgets('программа не назначена: раздела «Текущая программа» нет', (tester) async {
      stats.result = withRecords([record(1)]);

      final l10n = await pumpStats(tester);

      expect(find.text(l10n.statsCurrentProgram), findsNothing);
      expect(find.byType(CompletionTile), findsOneWidget);
    });

    testWidgets('пустой результат — пузыря нет, ответ тренера всё равно виден', (tester) async {
      stats.result = withRecords([
        record(1, result: '', comments: const [TrainerComment(id: 'k', text: 'Молодец')]),
      ]);

      await pumpStats(tester);

      expect(find.byType(ResultBubble), findsNothing);
      expect(find.text('Молодец'), findsOneWidget);
    });

    testWidgets('переносы строк в результате и в ответе сохраняются', (tester) async {
      stats.result = withRecords([
        record(
          1,
          result: 'Раз\nдва\nтри',
          comments: const [TrainerComment(id: 'k', text: 'Строка 1\nСтрока 2')],
        ),
      ]);

      await pumpStats(tester);

      expect(find.text('Раз\nдва\nтри'), findsOneWidget);
      expect(find.text('Строка 1\nСтрока 2'), findsOneWidget);
      // Три строки по line-height bodyMedium, а не одна.
      expect(tester.getSize(find.text('Раз\nдва\nтри')).height, greaterThan(3 * 14));
    });

    testWidgets('несколько ответов тренера — все, по порядку', (tester) async {
      stats.result = withRecords([
        record(
          1,
          comments: const [
            TrainerComment(id: 'a', text: 'Первый ответ'),
            TrainerComment(id: 'b', text: 'Второй ответ'),
          ],
        ),
      ]);

      await pumpStats(tester);

      expect(find.byType(TrainerReplyBubble), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Первый ответ')).dy,
        lessThan(tester.getTopLeft(find.text('Второй ответ')).dy),
      );
    });

    testWidgets('результат слева-направо: клиент справа, тренер слева', (tester) async {
      stats.result = withRecords([
        record(1, comments: const [TrainerComment(id: 'k', text: 'Ответ')]),
      ]);

      await pumpStats(tester);

      final mine = tester.getRect(
        find.descendant(of: find.byType(ResultBubble), matching: find.byType(DecoratedBox)),
      );
      final theirs = tester.getRect(
        find.descendant(of: find.byType(TrainerReplyBubble), matching: find.byType(DecoratedBox)),
      );
      expect(mine.right, lessThanOrEqualTo(402 - 16 + 0.5));
      expect(theirs.left, greaterThanOrEqualTo(16 - 0.5));
      expect(mine.center.dx, greaterThan(theirs.center.dx));
    });

    testWidgets('пузыри не шире 85 %', (tester) async {
      stats.result = withRecords([
        record(
          1,
          result: 'длинный результат ' * 60,
          comments: [TrainerComment(id: 'k', text: 'длинный ответ тренера ' * 60)],
        ),
      ]);

      await pumpStats(tester);

      const maxWidth = (402 - 32) * ResultBubble.maxWidthFactor;
      for (final type in [ResultBubble, TrainerReplyBubble]) {
        final bubble = find.descendant(of: find.byType(type), matching: find.byType(DecoratedBox));
        expect(tester.getSize(bubble).width, lessThanOrEqualTo(maxWidth + 0.5), reason: '$type');
      }
    });

    testWidgets('несколько программ: название под записью и счётчики по программам', (
      tester,
    ) async {
      stats.result = withRecords(
        [
          record(2, program: 'Силовая', programRu: 'Силовая ру'),
          record(1, program: 'Mentorix-app'),
        ],
        activity: const ClientActivity(
          totalCompletions: 5,
          byProgram: [
            ProgramActivity(programName: 'Силовая', programNameRu: 'Силовая ру', totalCompletions: 3),
            ProgramActivity(programName: 'Mentorix-app', programNameRu: '', totalCompletions: 2),
          ],
        ),
      );

      await pumpStats(tester);

      expect(find.text('Силовая'), findsWidgets);
      expect(find.text('Mentorix-app'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('по-русски название программы записи — program_name_ru', (tester) async {
      stats.result = withRecords(
        [record(1, program: 'Силовая', programRu: 'Силовая ру')],
        activity: const ClientActivity(
          totalCompletions: 2,
          byProgram: [
            ProgramActivity(programName: 'Силовая', programNameRu: 'Силовая ру', totalCompletions: 1),
            ProgramActivity(programName: 'Другая', programNameRu: '', totalCompletions: 1),
          ],
        ),
      );

      await pumpStats(tester, locale: const Locale('ru'));

      expect(find.text('Силовая ру'), findsWidgets);
    });

    testWidgets('несколько недель: разбивка «Week 1: 3 of 3»', (tester) async {
      stats.result = withRecords(
        const [],
        assignment: const AssignmentProgress(
          programName: 'P',
          programNameRu: '',
          completedDays: 4,
          totalTrainingDays: 7,
          completionPercent: 57.1428,
          weeks: [
            WeekProgress(weekNumber: 1, totalDays: 3, completedDays: 3),
            WeekProgress(weekNumber: 2, totalDays: 4, completedDays: 1),
          ],
        ),
      );

      await pumpStats(tester);

      expect(find.text('Week 1: 3 of 3'), findsOneWidget);
      expect(find.text('Week 2: 1 of 4'), findsOneWidget);
      expect(find.text('57.1%'), findsOneWidget);
    });

    testWidgets('проценты: 0, 33.3, 100', (tester) async {
      for (final entry in {0.0: '0%', 33.3: '33.3%', 100.0: '100%'}.entries) {
        stats.result = withRecords(
          const [],
          assignment: AssignmentProgress(
            programName: 'P',
            programNameRu: '',
            completedDays: 1,
            totalTrainingDays: 3,
            completionPercent: entry.key,
          ),
        );
        await app.pump(tester, initialPath: RouteNames.statsPath('aziz'));

        expect(find.text(entry.value), findsOneWidget, reason: entry.value);
        await tester.pumpWidget(const SizedBox());
        await app.dispose();
        app = WorkoutAppHarness(repository, stats: stats);
      }
    });

    testWidgets('30 записей показываются, список прокручивается', (tester) async {
      stats.result = withRecords([for (var i = 30; i >= 1; i--) record(i)]);

      await pumpStats(tester);
      await tester.dragUntilVisible(
        find.text('Week 1, day 1'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );

      expect(find.text('Week 1, day 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('шапка, назад, обновление', () {
    testWidgets('крупная шапка «Statistics», кнопка «назад»', (tester) async {
      await pumpStats(tester);

      expect(find.byType(LargeTitleSliverAppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('левый край заголовков, карточек и записей — 16 px', (tester) async {
      await pumpStats(tester);

      expect(tester.getTopLeft(find.text('Current program')).dx, 16);
      expect(tester.getTopLeft(find.byType(Card).first).dx, 16);
      expect(tester.getTopLeft(find.text('Week 1, day 2')).dx, 16);
    });

    testWidgets('«назад» без истории ведёт к программе', (tester) async {
      await pumpStats(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ProgramScreen), findsOneWidget);
    });

    testWidgets('iOS: свайп назад возвращает на программу', (tester) async {
      await app.pump(tester, platform: TargetPlatform.iOS);
      await tester.tap(find.byTooltip('Workout results'));
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsOneWidget);

      await tester.dragFrom(const Offset(2, 400), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.byType(StatsScreen), findsNothing);
      expect(find.byType(ProgramScreen), findsOneWidget);
    });

    testWidgets('Android: pull-to-refresh, индикатор ждёт кубит', (tester) async {
      await pumpStats(tester);
      stats.gate = Completer<void>();

      await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(stats.calls, 2);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      expect(tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).edgeOffset, kToolbarHeight);

      stats.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });

    testWidgets('iOS: родной индикатор под шапкой', (tester) async {
      await pumpStats(tester, platform: TargetPlatform.iOS);
      expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false), findsOneWidget);
      final slivers = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).slivers;
      expect(slivers[0], isA<LargeTitleSliverAppBar>());
      expect(slivers[1], isA<CupertinoSliverRefreshControl>());

      stats.gate = Completer<void>();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(stats.calls, 2);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      stats.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('обновление подтягивает новый ответ тренера', (tester) async {
      stats.result = withRecords([record(1)]);
      await pumpStats(tester);
      expect(find.byType(TrainerReplyBubble), findsNothing);

      stats.result = withRecords([
        record(1, comments: const [TrainerComment(id: 'k', text: 'Новый ответ')]),
      ]);
      await pullToRefresh(tester);

      expect(find.text('Новый ответ'), findsOneWidget);
    });
  });

  group('вход в статистику', () {
    testWidgets('программа: значок графика в шапке открывает статистику', (tester) async {
      await app.pump(tester);

      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(StatsScreen), findsOneWidget);
      expect(app.router.state.matchedLocation, RouteNames.statsPath('aziz'));
    });

    testWidgets('подсказка значка — «Результаты тренировок» / по-русски', (tester) async {
      await app.pump(tester);
      expect(find.byTooltip('Workout results'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await app.dispose();
      app = WorkoutAppHarness(repository, stats: stats);
      await app.pump(tester, locale: const Locale('ru'));
      expect(find.byTooltip('Результаты тренировок'), findsOneWidget);
    });

    testWidgets('значок остаётся на месте при прокрутке', (tester) async {
      await app.pump(tester, size: const Size(402, 480));
      final before = tester.getCenter(find.byIcon(Icons.bar_chart_outlined));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.getCenter(find.byIcon(Icons.bar_chart_outlined)), before);
    });

    testWidgets('выполненный день: «Результаты тренировок» ведёт в статистику', (tester) async {
      repository.programResult = stageProgram(completed: {'day-1'});
      await app.pump(tester, initialPath: RouteNames.workoutDayPath('aziz', 'day-1'));

      await tester.tap(find.text('Workout results'));
      await tester.pumpAndSettle();

      expect(find.byType(StatsScreen), findsOneWidget);
    });

    testWidgets('невыполненный день: ссылки на статистику нет', (tester) async {
      await app.pump(tester, initialPath: RouteNames.workoutDayPath('aziz', 'day-1'));

      expect(find.text('Workout results'), findsNothing);
      expect(find.byType(DayScreen), findsOneWidget);
    });

    testWidgets('после отметки: статистика запрашивается заново при каждом открытии', (
      tester,
    ) async {
      await app.pump(tester);
      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pumpAndSettle();

      expect(stats.calls, 2);
    });
  });

  group('вёрстка', () {
    for (final entry in {'светлая': AppTheme.light, 'тёмная': AppTheme.dark}.entries) {
      for (final locale in const [Locale('ru'), Locale('en')]) {
        testWidgets(
          '${entry.key}, ${locale.languageCode}: 320 px, шрифт ×2, длинные тексты',
          (tester) async {
            stats.result = withRecords(
              [
                for (var i = 30; i >= 1; i--)
                  record(
                    i,
                    result: 'Очень длинный результат тренировки ' * 29,
                    comments: [
                      TrainerComment(
                        id: 'k$i',
                        text: 'Очень длинный ответ тренера ' * 70,
                        createdAt: DateTime.utc(2026, 10, 29),
                      ),
                    ],
                  ),
              ],
              activity: const ClientActivity(totalCompletions: 30, completionsLast7Days: 7, completionsLast30Days: 30, weekStreak: 4),
              assignment: const AssignmentProgress(
                programName: 'Очень длинное название программы тренировок для проверки',
                programNameRu: '',
                completedDays: 1,
                totalTrainingDays: 3,
                completionPercent: 33.3,
                weeks: [
                  WeekProgress(weekNumber: 1, totalDays: 3, completedDays: 1),
                  WeekProgress(weekNumber: 2, totalDays: 3, completedDays: 0),
                ],
              ),
            );

            await pumpStats(
              tester,
              locale: locale,
              theme: entry.value,
              size: const Size(320, 568),
              textScale: 2,
            );
            for (var i = 0; i < 4; i++) {
              await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
              await tester.pump();
            }

            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('скелетон при шрифте ×2 не переполняется', (tester) async {
      stats.gate = Completer<void>();

      await pumpStats(tester, size: const Size(320, 480), textScale: 2, settle: false);

      expect(tester.takeException(), isNull);
    });

    testWidgets('пустое состояние и ошибка при шрифте ×2', (tester) async {
      stats.result = sample('client_analytics_empty.json');
      await pumpStats(tester, size: const Size(320, 480), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('тексты результата не попадают в буфер/системные каналы', (tester) async {
    // Просмотр статистики ничего не копирует и не отправляет сам.
    var clipboardWrites = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardWrites++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpStats(tester);

    expect(clipboardWrites, 0);
  });
}
