import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/core/widgets/notice_banner.dart';
import 'package:mentorix_app/core/widgets/pinned_action_bar.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_assignment.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/screens/complete_day_screen.dart';
import 'package:mentorix_app/features/workout/presentation/screens/day_screen.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/complete_day_form.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/completed_status.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/confirm_completion_dialog.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_complete_bar.dart';
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
  String completePath(String key) => RouteNames.completeDayPath('aziz', key);

  /// Сервер записал отметку: день попадает в `completed_days`.
  void serverMarksDone() {
    repository.onCompleted = (target, _) {
      final current = repository.programResult;
      repository.programResult = TrainerProgram(
        trainerId: current.trainerId,
        trainerName: current.trainerName,
        assignment: current.assignment,
        program: current.program,
        completedDayKeys: {...current.completedDayKeys, target.dayKey},
      );
    };
  }

  /// Тренер переназначил программу: новая версия и цикл, те же дни.
  TrainerProgram reassigned() => TrainerProgram(
    trainerId: 'aziz',
    trainerName: 'Aziz Geidar',
    assignment: const ProgramAssignment(
      assignmentId: 'assignment-2',
      programVersionId: 'version-2',
      completionCycleId: 'cycle-2',
    ),
    program: stageProgram().program,
  );

  Future<AppLocalizations> pumpDay(
    WidgetTester tester, {
    String key = 'day-1',
    Locale locale = const Locale('en'),
    ThemeData? theme,
    Size size = const Size(402, 874),
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.android,
  }) => app.pump(
    tester,
    initialPath: dayPath(key),
    locale: locale,
    theme: theme,
    size: size,
    textScale: textScale,
    platform: platform,
  );

  /// Экран дня → форма результата. Под формой экран дня: есть куда вернуться.
  Future<AppLocalizations> openForm(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeData? theme,
    Size size = const Size(402, 874),
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    final l10n = await pumpDay(
      tester,
      locale: locale,
      theme: theme,
      size: size,
      textScale: textScale,
      platform: platform,
    );
    await tester.tap(find.text(l10n.dayCompleteAction));
    await tester.pumpAndSettle();
    expect(find.byType(CompleteDayForm), findsOneWidget);
    return l10n;
  }

  /// Кнопка формы. Экран дня под формой остаётся в дереве, поэтому ищем внутри
  /// панели формы.
  Finder nextButton(AppLocalizations l10n) => find.descendant(
    of: find.byType(CompleteDayForm),
    matching: find.byType(FilledButton),
  );

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<FilledButton>(button).onPressed != null;

  Future<void> typeResult(WidgetTester tester, String text) async {
    // Список ленивый: при крупном шрифте поле может быть ниже экрана.
    if (find.byType(TextField).evaluate().isEmpty) {
      await tester.dragUntilVisible(
        find.byType(TextField),
        find.byType(CustomScrollView).last,
        const Offset(0, -100),
      );
    }
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  Future<void> sendFromForm(
    WidgetTester tester,
    AppLocalizations l10n,
    String text,
  ) async {
    await typeResult(tester, text);
    await tester.tap(nextButton(l10n));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.completeConfirmAction));
    await tester.pumpAndSettle();
  }

  TextField field(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField));

  group('«Отметить выполненной» на экране дня', () {
    testWidgets('есть у невыполненного тренировочного дня', (tester) async {
      final l10n = await pumpDay(tester);

      expect(find.byType(DayCompleteBar), findsOneWidget);
      expect(find.text(l10n.dayCompleteAction), findsOneWidget);
      expect(find.byType(CompletedStatus), findsNothing);
    });

    testWidgets('по-русски', (tester) async {
      await pumpDay(tester, locale: const Locale('ru'));

      expect(find.text('Отметить выполненной'), findsOneWidget);
    });

    testWidgets('нет у выполненного дня: вместо неё «Выполнено»', (tester) async {
      repository.programResult = stageProgram(completed: {'day-1'});

      await pumpDay(tester);

      expect(find.byType(DayCompleteBar), findsNothing);
      expect(find.byType(CompletedStatus), findsOneWidget);
    });

    testWidgets('нет у дня отдыха', (tester) async {
      await pumpDay(tester, key: 'day-3');

      expect(find.byType(DayCompleteBar), findsNothing);
    });

    testWidgets('нет, если у назначения не хватает идентификаторов', (tester) async {
      repository.programResult = TrainerProgram(
        trainerId: 'aziz',
        assignment: const ProgramAssignment(
          assignmentId: 'a',
          programVersionId: '',
          completionCycleId: 'c',
        ),
        program: stageProgram().program,
      );

      await pumpDay(tester);

      expect(find.byType(DayCompleteBar), findsNothing);
      expect(find.text('Back Squat'), findsOneWidget, reason: 'день при этом виден');
    });

    testWidgets('нет у дня без упражнений', (tester) async {
      repository.programResult = trainerProgram([
        week(1, [trainingDay(1, key: 'k', blocks: [block(BlockType.emom, exercises: [])])]),
      ]);

      await pumpDay(tester, key: 'k');

      expect(find.byType(DayCompleteBar), findsNothing);
    });

    testWidgets('после обновления (отметили в боте) кнопка исчезает', (tester) async {
      await pumpDay(tester);
      expect(find.byType(DayCompleteBar), findsOneWidget);

      repository.programResult = stageProgram(completed: {'day-1'});
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(DayCompleteBar), findsNothing);
      expect(find.byType(CompletedStatus), findsOneWidget);
    });

    testWidgets('нажатие открывает форму результата', (tester) async {
      final l10n = await pumpDay(tester);

      await tester.tap(find.text(l10n.dayCompleteAction));
      await tester.pumpAndSettle();

      expect(find.byType(CompleteDayForm), findsOneWidget);
      expect(app.router.state.matchedLocation, completePath('day-1'));
    });
  });

  group('кнопка закреплена внизу, контент под неё не уходит', () {
    TrainerProgram longDay() => trainerProgram([
      week(1, [
        trainingDay(
          1,
          key: 'k',
          blocks: [
            for (var i = 0; i < 20; i++)
              block(
                BlockType.single,
                exercises: [exercise('Упражнение $i', sets: '3', reps: '10')],
              ),
          ],
        ),
      ]),
    ]);

    testWidgets('на длинном дне кнопка видна без прокрутки и прижата к низу', (tester) async {
      repository.programResult = longDay();
      await pumpDay(tester, key: 'k', size: const Size(402, 600));

      final bar = tester.getRect(find.byType(PinnedActionBar));
      final button = tester.getRect(find.byType(FilledButton));

      expect(bar.bottom, 600);
      expect(button.bottom, lessThanOrEqualTo(600));
      expect(button.top, greaterThan(400), reason: 'внизу, а не посреди экрана');
      expect(find.text('Упражнение 19'), findsNothing, reason: 'день длинный, до конца далеко');
    });

    testWidgets('прокручиваемая область заканчивается над панелью', (tester) async {
      repository.programResult = longDay();
      await pumpDay(tester, key: 'k', size: const Size(402, 600));

      final scroll = tester.getRect(find.byType(CustomScrollView));
      final bar = tester.getRect(find.byType(PinnedActionBar));

      expect(scroll.bottom, lessThanOrEqualTo(bar.top + 0.5));
    });

    testWidgets('последнее упражнение при прокрутке до конца не под панелью', (tester) async {
      repository.programResult = longDay();
      await pumpDay(tester, key: 'k', size: const Size(402, 600));

      await tester.dragUntilVisible(
        find.text('Упражнение 19'),
        find.byType(CustomScrollView),
        const Offset(0, -150),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final last = tester.getRect(find.text('Упражнение 19'));
      final bar = tester.getRect(find.byType(PinnedActionBar));
      expect(last.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('кнопка на сетке 16 px, на всю ширину, не ниже 48', (tester) async {
      await pumpDay(tester);

      final button = tester.getRect(find.byType(FilledButton));

      expect(button.left, 16);
      expect(button.right, 402 - 16);
      expect(button.height, greaterThanOrEqualTo(48));
    });

    testWidgets('отступ под индикатор «домой» учтён один раз', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 800)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(bottom: 34)
        ..viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);

      await app.pump(tester, initialPath: dayPath('day-1'), size: const Size(402, 800));
      tester.view
        ..padding = const FakeViewPadding(bottom: 34)
        ..viewPadding = const FakeViewPadding(bottom: 34);
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byType(PinnedActionBar));
      final button = tester.getRect(find.byType(FilledButton));
      expect(bar.bottom, 800, reason: 'панель доходит до края экрана');
      expect(button.bottom, 800 - 34 - 16, reason: 'один отступ 34 и один 16');
    });

    testWidgets('у выполненного дня панели нет, контент занимает весь экран', (tester) async {
      repository.programResult = stageProgram(completed: {'day-1'});
      await pumpDay(tester);

      expect(find.byType(PinnedActionBar), findsNothing);
    });

    testWidgets('при шрифте ×2 и 320 px панель не переполняется', (tester) async {
      await pumpDay(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        locale: const Locale('ru'),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DayCompleteBar), findsOneWidget);
    });
  });

  group('форма результата', () {
    testWidgets('начальное состояние: заголовок, подсказка, пустое поле, «Далее» недоступна', (
      tester,
    ) async {
      final l10n = await openForm(tester);

      expect(find.text(l10n.completeTitle), findsWidgets);
      expect(find.text('Week 1, day 1'), findsWidgets);
      expect(find.text(l10n.completeHint), findsOneWidget);
      expect(field(tester).controller!.text, isEmpty);
      expect(find.text(l10n.completeCounter(0, 1000)), findsOneWidget);
      expect(enabled(tester, nextButton(l10n)), isFalse);
      expect(find.byType(NoticeBanner), findsNothing);
    });

    testWidgets('по-русски', (tester) async {
      await openForm(tester, locale: const Locale('ru'));

      expect(find.text('Результат тренировки'), findsWidgets);
      expect(find.text('Далее'), findsOneWidget);
      expect(find.text('0 / 1000'), findsOneWidget);
    });

    testWidgets('пустой текст и одни пробелы: «Далее» недоступна', (tester) async {
      final l10n = await openForm(tester);

      for (final text in ['   ', '\n\n', ' \t ']) {
        await typeResult(tester, text);
        expect(enabled(tester, nextButton(l10n)), isFalse, reason: '«$text»');
      }
    });

    testWidgets('есть непробельный символ — «Далее» доступна', (tester) async {
      final l10n = await openForm(tester);

      await typeResult(tester, 'а');

      expect(enabled(tester, nextButton(l10n)), isTrue);
    });

    testWidgets('счётчик показывает число символов', (tester) async {
      final l10n = await openForm(tester);

      await typeResult(tester, 'Сделал 5x5');

      expect(find.text(l10n.completeCounter(10, 1000)), findsOneWidget);
    });

    testWidgets('больше 1000 символов обрезается до 1000', (tester) async {
      final l10n = await openForm(tester);

      await typeResult(tester, 'я' * 1200);

      expect(field(tester).controller!.text.length, 1000);
      expect(find.text(l10n.completeCounter(1000, 1000)), findsOneWidget);
    });

    testWidgets('эмодзи считаются как символы Unicode: 1100 штук → 1000', (tester) async {
      final l10n = await openForm(tester);

      await typeResult(tester, '💪' * 1100);

      expect(field(tester).controller!.text.runes.length, 1000);
      expect(find.text(l10n.completeCounter(1000, 1000)), findsOneWidget);
    });

    testWidgets('несколько строк разрешены', (tester) async {
      final l10n = await openForm(tester);

      await typeResult(tester, 'Раз\nдва\nтри');

      expect(field(tester).controller!.text, 'Раз\nдва\nтри');
      expect(find.text(l10n.completeCounter(11, 1000)), findsOneWidget);
      expect(field(tester).maxLines, greaterThan(1));
    });
  });

  group('подтверждение', () {
    testWidgets('«Далее» открывает окно: отменить нельзя, виден текст, запроса ещё нет', (
      tester,
    ) async {
      final l10n = await openForm(tester);
      await typeResult(tester, '  Сделал 5x5  ');

      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmCompletionDialog), findsOneWidget);
      expect(find.text(l10n.completeConfirmTitle), findsOneWidget);
      expect(find.text(l10n.completeConfirmBody), findsOneWidget);
      expect(find.text('Сделал 5x5'), findsOneWidget, reason: 'в том виде, как уйдёт');
      expect(repository.completeCalls, isEmpty);
    });

    testWidgets('«Back» закрывает окно: запроса нет, текст в поле остался', (tester) async {
      final l10n = await openForm(tester);
      await typeResult(tester, 'Сделал 5x5');
      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.completeBackAction));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmCompletionDialog), findsNothing);
      expect(repository.completeCalls, isEmpty);
      expect(field(tester).controller!.text, 'Сделал 5x5');
      expect(find.byType(CompleteDayForm), findsOneWidget);
    });

    testWidgets('касание вне окна — тоже отказ, запроса нет', (tester) async {
      final l10n = await openForm(tester);
      await typeResult(tester, 'ок');
      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmCompletionDialog), findsNothing);
      expect(repository.completeCalls, isEmpty);
    });

    testWidgets('длинный результат в окне прокручивается, не переполняется', (tester) async {
      final l10n = await openForm(
        tester,
        size: const Size(320, 568),
        textScale: 2,
      );
      await typeResult(tester, 'Очень длинный результат тренировки. ' * 28);

      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ConfirmCompletionDialog), findsOneWidget);
    });
  });

  group('успешная отметка', () {
    testWidgets('«Отметить» → один запрос с идентификаторами и текстом', (tester) async {
      serverMarksDone();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, '  Сделал 5x5, последний подход тяжело  ');

      expect(repository.completeCalls, hasLength(1));
      final call = repository.completeCalls.single;
      expect(call.trainerId, 'aziz');
      expect(call.target.assignmentId, 'assignment-1');
      expect(call.target.programVersionId, 'version-1');
      expect(call.target.completionCycleId, 'cycle-1');
      expect(call.target.dayKey, 'day-1');
      expect(call.text, 'Сделал 5x5, последний подход тяжело');
    });

    testWidgets('возврат на экран дня, уведомление, день выполнен по ответу сервера', (
      tester,
    ) async {
      serverMarksDone();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, 'Сделал');

      expect(find.byType(CompleteDayForm), findsNothing);
      expect(find.byType(DayScreen), findsOneWidget);
      expect(app.router.state.matchedLocation, dayPath('day-1'));
      expect(find.text(l10n.completeSavedMessage), findsOneWidget);
      expect(find.byType(CompletedStatus), findsOneWidget);
      expect(find.byType(DayCompleteBar), findsNothing, reason: 'отметить второй раз нельзя');
    });

    testWidgets('на экране программы день с галочкой и прогрессом 1 из 3', (tester) async {
      serverMarksDone();
      final l10n = await openForm(tester);
      await sendFromForm(tester, l10n, 'Сделал');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Completed 1 of 3'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('виброотклик один раз', (tester) async {
      var haptics = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      serverMarksDone();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, 'Сделал');

      expect(haptics, 1);
    });

    testWidgets('при отправке: индикатор в кнопке, поле и «назад» заблокированы', (tester) async {
      serverMarksDone();
      final gate = Completer<void>();
      repository.completeGate = gate;
      final l10n = await openForm(tester);
      await typeResult(tester, 'Сделал');
      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.completeConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.descendant(
          of: nextButton(l10n),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(enabled(tester, nextButton(l10n)), isFalse);
      expect(field(tester).enabled, isFalse);

      // Системная «назад» не закрывает экран, пока идёт запрос.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CompleteDayForm), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CompleteDayForm), findsNothing);
      expect(repository.completeCalls, hasLength(1));
    });

    testWidgets('форма не подменяется «уже отмечен» в момент успеха', (tester) async {
      serverMarksDone();
      final l10n = await openForm(tester);
      await typeResult(tester, 'Сделал');
      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.completeConfirmAction));

      // Покадрово: программа перезагружается, день становится выполненным, но
      // «защёлкнутая» форма остаётся до закрытия кубитом.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text(l10n.errorWorkoutAlreadyCompleted), findsNothing, reason: 'кадр $i');
      }
      await tester.pumpAndSettle();
      expect(find.text(l10n.completeSavedMessage), findsOneWidget);
    });

    testWidgets('обновление программы не удалось: «Отмечено, но обновить не удалось»', (
      tester,
    ) async {
      repository.onCompleted = (_, _) =>
          repository.programFailure = const WorkoutNetworkFailure();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, 'Сделал');

      expect(find.text(l10n.completeSavedRefreshFailed), findsOneWidget);
      expect(find.byType(DayScreen), findsOneWidget);
      expect(repository.completeCalls, hasLength(1));
      // Выполненность по-прежнему только с сервера: пока не обновили, её нет.
      expect(find.byType(CompletedStatus), findsNothing);
    });
  });

  group('ошибки', () {
    testWidgets('нет связи: уведомление, текст остался, повтор проходит', (tester) async {
      repository.completeFailure = const WorkoutNetworkFailure();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, 'Сделал 5x5');

      expect(find.text(l10n.errorNetwork), findsOneWidget);
      expect(field(tester).controller!.text, 'Сделал 5x5');
      expect(enabled(tester, nextButton(l10n)), isTrue);
      expect(find.byType(CompleteDayForm), findsOneWidget);

      repository.completeFailure = null;
      serverMarksDone();
      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.completeConfirmAction));
      await tester.pumpAndSettle();

      expect(repository.completeCalls, hasLength(2));
      expect(find.byType(DayScreen), findsOneWidget);
    });

    testWidgets('сервер отклонил текст (400): сообщение, текст остался', (tester) async {
      repository.completeFailure = const WorkoutInvalidResultFailure();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, 'ок');

      expect(find.text(l10n.errorWorkoutInvalidResult), findsOneWidget);
      expect(field(tester).controller!.text, 'ок');
    });

    testWidgets('429: сообщение, поле на месте, само не повторяется', (tester) async {
      repository.completeFailure = const WorkoutTooManyRequestsFailure();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, 'ок');

      expect(find.text(l10n.errorTooManyRequests), findsOneWidget);
      expect(repository.completeCalls, hasLength(1));
    });

    testWidgets('сырой текст ошибки не показывается', (tester) async {
      repository.completeFailure = const WorkoutUnknownFailure();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, 'ок');

      expect(find.text(l10n.errorUnknown), findsOneWidget);
    });
  });

  group('409 program_changed', () {
    testWidgets('баннер, введённый текст не потерян, само не отправляется', (tester) async {
      repository.completeFailure = const WorkoutProgramChangedFailure();
      final l10n = await openForm(tester);
      repository.programResult = reassigned();

      await sendFromForm(tester, l10n, 'Мой длинный\nрезультат 💪');

      expect(find.byType(NoticeBanner), findsOneWidget);
      expect(
        find.descendant(of: find.byType(NoticeBanner), matching: find.text(l10n.errorWorkoutProgramChanged)),
        findsOneWidget,
      );
      expect(field(tester).controller!.text, 'Мой длинный\nрезультат 💪');
      expect(repository.completeCalls, hasLength(1), reason: 'ничего не переотправлено');
      expect(find.byType(CompleteDayForm), findsOneWidget);
      expect(find.byType(ConfirmCompletionDialog), findsNothing);
    });

    testWidgets('новая отправка снова через подтверждение и с новыми идентификаторами', (
      tester,
    ) async {
      repository.completeFailure = const WorkoutProgramChangedFailure();
      final l10n = await openForm(tester);
      repository.programResult = reassigned();
      await sendFromForm(tester, l10n, 'Результат');

      repository.completeFailure = null;
      serverMarksDone();
      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmCompletionDialog), findsOneWidget, reason: 'подтверждение снова');
      expect(repository.completeCalls, hasLength(1));
      await tester.tap(find.text(l10n.completeConfirmAction));
      await tester.pumpAndSettle();

      expect(repository.completeCalls, hasLength(2));
      final second = repository.completeCalls.last.target;
      expect(second.assignmentId, 'assignment-2');
      expect(second.programVersionId, 'version-2');
      expect(second.completionCycleId, 'cycle-2');
      expect(repository.completeCalls.last.text, 'Результат');
      expect(find.byType(DayScreen), findsOneWidget);
    });

    testWidgets('день пропал из новой программы: пояснение и возврат на день', (tester) async {
      repository.completeFailure = const WorkoutProgramChangedFailure();
      final l10n = await openForm(tester);
      repository.programResult = trainerProgram([
        week(1, [trainingDay(1, key: 'другой')]),
      ]);

      await sendFromForm(tester, l10n, 'Результат');

      expect(find.byType(CompleteDayForm), findsNothing);
      expect(find.byType(DayScreen), findsOneWidget);
      expect(find.text(l10n.errorWorkoutDayNotFound), findsWidgets);
      expect(repository.completeCalls, hasLength(1));
    });

    testWidgets('назначение снято: «Программа не назначена»', (tester) async {
      repository.completeFailure = const WorkoutProgramChangedFailure();
      final l10n = await openForm(tester);
      repository.programResult = const TrainerProgram(trainerId: 'aziz');

      await sendFromForm(tester, l10n, 'Результат');

      expect(find.byType(CompleteDayForm), findsNothing);
      expect(find.text(l10n.programNotAssignedTitle), findsWidgets);
    });

    testWidgets('нет связи при перезагрузке: сообщение, повтор возможен', (tester) async {
      repository.completeFailure = const WorkoutProgramChangedFailure();
      final l10n = await openForm(tester);
      repository.programFailure = const WorkoutNetworkFailure();

      await sendFromForm(tester, l10n, 'Результат');

      expect(find.byType(CompleteDayForm), findsOneWidget);
      expect(find.text(l10n.errorWorkoutProgramChanged), findsOneWidget);
      expect(field(tester).controller!.text, 'Результат');
    });
  });

  group('409 workout_already_completed и 404 day_not_found', () {
    testWidgets('«уже отмечен»: пояснение, закрытие, на экране дня «Выполнено»', (tester) async {
      repository.completeFailure = const WorkoutAlreadyCompletedFailure();
      final l10n = await openForm(tester);
      // Пока клиент писал, день отметили в Telegram-боте.
      repository.programResult = stageProgram(completed: {'day-1'});

      await sendFromForm(tester, l10n, 'Результат');

      expect(find.byType(CompleteDayForm), findsNothing);
      expect(find.text(l10n.errorWorkoutAlreadyCompleted), findsOneWidget);
      expect(find.byType(DayScreen), findsOneWidget);
      expect(find.byType(CompletedStatus), findsOneWidget);
    });

    testWidgets('день удалён: пояснение и закрытие', (tester) async {
      repository.completeFailure = const WorkoutDayNotFoundFailure();
      final l10n = await openForm(tester);

      await sendFromForm(tester, l10n, 'Результат');

      expect(find.byType(CompleteDayForm), findsNothing);
      expect(find.text(l10n.errorWorkoutDayNotFound), findsWidgets);
    });
  });

  group('открытие формы напрямую (по ссылке или после восстановления)', () {
    testWidgets('программы ещё нет: скелетон, потом форма', (tester) async {
      final gate = Completer<void>();
      repository.programGate = gate;

      final l10n = await app.pump(
        tester,
        initialPath: completePath('day-1'),
        settle: false,
      );
      expect(find.byType(CompleteDayForm), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CompleteDayForm), findsOneWidget);
      expect(find.text(l10n.completeTitle), findsWidgets);
      expect(repository.programCalls, 1);
    });

    testWidgets('«назад» без истории ведёт на экран дня', (tester) async {
      await app.pump(tester, initialPath: completePath('day-1'));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(DayScreen), findsOneWidget);
      expect(app.router.state.matchedLocation, dayPath('day-1'));
    });

    testWidgets('день уже выполнен: формы нет, пояснение', (tester) async {
      repository.programResult = stageProgram(completed: {'day-1'});

      final l10n = await app.pump(tester, initialPath: completePath('day-1'));

      expect(find.byType(CompleteDayForm), findsNothing);
      expect(find.byType(CompleteDayScreen), findsOneWidget);
      expect(find.text(l10n.errorWorkoutAlreadyCompleted), findsOneWidget);
    });

    testWidgets('день отдыха и неизвестный день: формы нет, «дня больше нет»', (tester) async {
      for (final key in ['day-3', 'нет-такого']) {
        final l10n = await app.pump(tester, initialPath: completePath(key));

        expect(find.byType(CompleteDayForm), findsNothing, reason: key);
        expect(find.text(l10n.errorWorkoutDayNotFound), findsOneWidget, reason: key);
        await tester.pumpWidget(const SizedBox());
        await app.dispose();
        app = WorkoutAppHarness(repository);
      }
    });

    testWidgets('программа не назначена и ошибка загрузки', (tester) async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');
      final l10n = await app.pump(tester, initialPath: completePath('day-1'));
      expect(find.text(l10n.programNotAssignedTitle), findsWidgets);
      expect(find.byType(CompleteDayForm), findsNothing);
    });

    testWidgets('ошибка загрузки: «Повторить» открывает форму', (tester) async {
      repository.programFailure = const WorkoutNetworkFailure();
      final l10n = await app.pump(tester, initialPath: completePath('day-1'));
      expect(find.byType(ErrorState), findsOneWidget);

      repository.programFailure = null;
      await tester.tap(find.text(l10n.retryAction));
      await tester.pumpAndSettle();

      expect(find.byType(CompleteDayForm), findsOneWidget);
    });
  });

  group('клавиатура, жесты, вёрстка', () {
    testWidgets('кнопка поднимается над клавиатурой и остаётся видимой', (tester) async {
      final l10n = await openForm(tester, size: const Size(402, 800));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final button = tester.getRect(nextButton(l10n));

      expect(button.bottom, lessThanOrEqualTo(800 - 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('поле остаётся достижимым при клавиатуре и малом экране', (tester) async {
      await openForm(tester, size: const Size(320, 480));
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      await typeResult(tester, 'ок');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(field(tester).controller!.text, 'ок');
    });

    testWidgets('iOS: свайп назад от левого края возвращает на экран дня', (tester) async {
      await openForm(tester, platform: TargetPlatform.iOS);

      await tester.dragFrom(const Offset(2, 400), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.byType(CompleteDayForm), findsNothing);
      expect(find.byType(DayScreen), findsOneWidget);
    });

    testWidgets('iOS: во время отправки свайп назад не закрывает экран', (tester) async {
      serverMarksDone();
      final gate = Completer<void>();
      repository.completeGate = gate;
      final l10n = await openForm(tester, platform: TargetPlatform.iOS);
      await typeResult(tester, 'ок');
      await tester.tap(nextButton(l10n));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.completeConfirmAction));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.dragFrom(const Offset(2, 400), const Offset(600, 0));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CompleteDayForm), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    for (final entry in {'светлая': AppTheme.light, 'тёмная': AppTheme.dark}.entries) {
      for (final locale in const [Locale('ru'), Locale('en')]) {
        testWidgets('${entry.key}, ${locale.languageCode}: 320 px, шрифт ×2', (tester) async {
          await openForm(
            tester,
            locale: locale,
            theme: entry.value,
            size: const Size(320, 568),
            textScale: 2,
          );
          await typeResult(tester, 'Длинный результат ' * 50);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(PinnedActionBar), findsOneWidget);
        });
      }
    }
  });
}
