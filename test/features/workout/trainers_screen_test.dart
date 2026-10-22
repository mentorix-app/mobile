import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/core/widgets/error_state.dart';
import 'package:mentorix_app/core/widgets/skeleton_box.dart';
import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/home/presentation/screens/home_screen.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/trainers_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/trainer_card.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/workout_fakes.dart';

void main() {
  late FakeWorkoutRepository repository;
  late GoRouter router;

  setUp(() => repository = FakeWorkoutRepository()..trainersResult = [aziz]);

  Future<AppLocalizations> pumpHome(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeData? theme,
    Size size = const Size(402, 874),
    double textScale = 1,
    bool settle = true,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    router = GoRouter(
      routes: [
        GoRoute(
          path: RouteNames.home,
          builder: (context, state) => BlocProvider(
            create: (_) => TrainersCubit(repository)..load(),
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: RouteNames.profile,
          builder: (_, _) => const Scaffold(body: Text('profile-screen')),
        ),
        GoRoute(
          path: RouteNames.invite,
          builder: (_, _) => const Scaffold(body: Text('invite-screen')),
        ),
      ],
    );

    SharedPreferences.setMockInitialValues({});
    final themeCubit = ThemeCubit(
      ThemeRepositoryImpl(await SharedPreferences.getInstance()),
    );
    addTearDown(themeCubit.close);

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: themeCubit,
        child: MaterialApp.router(
        theme: (theme ?? AppTheme.light).copyWith(platform: platform),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return lookupAppLocalizations(locale);
  }

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('загрузка: скелетон трёх карточек вместо спиннера', (tester) async {
    repository.trainersGate = Completer<void>();

    await pumpHome(tester, settle: false);

    expect(find.byType(SkeletonBox), findsNWidgets(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TrainerCard), findsNothing);

    repository.trainersGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonBox), findsNothing);
    expect(find.text('Aziz Geidar'), findsOneWidget);
  });

  testWidgets('один тренер — всё равно список из одной карточки', (tester) async {
    await pumpHome(tester);

    expect(find.text('My trainers'), findsOneWidget);
    expect(find.byType(TrainerCard), findsOneWidget);
    expect(find.text('Aziz Geidar'), findsOneWidget);
    expect(router.state.matchedLocation, RouteNames.home);
  });

  testWidgets('несколько тренеров: порядок сервера, ключ по trainer_id', (tester) async {
    repository.trainersResult = const [
      LinkedTrainer(trainerId: 't-2', trainerDisplayName: 'Второй'),
      aziz,
    ];

    await pumpHome(tester);

    final cards = tester.widgetList<TrainerCard>(find.byType(TrainerCard)).toList();
    expect(cards.map((c) => c.trainer.trainerId), ['t-2', aziz.trainerId]);
    expect(cards.map((c) => c.key), [
      const ValueKey('t-2'),
      ValueKey(aziz.trainerId),
    ]);
  });

  testWidgets('пустое имя заменяется словом «Тренер» / «Trainer»', (tester) async {
    repository.trainersResult = const [
      LinkedTrainer(trainerId: 't-1', trainerDisplayName: '  '),
    ];

    await pumpHome(tester);
    expect(find.text('Trainer'), findsOneWidget);

    await pumpHome(tester, locale: const Locale('ru'));
    expect(find.text('Тренер'), findsOneWidget);
    expect(find.text('Мои тренеры'), findsOneWidget);
  });

  testWidgets('тренера нет: пояснение и переход к приглашению', (tester) async {
    repository.trainersResult = const [];

    final l10n = await pumpHome(tester);

    expect(find.text(l10n.trainersEmptyTitle), findsOneWidget);
    expect(find.text(l10n.trainersEmptyBody), findsOneWidget);
    expect(find.byType(TrainerCard), findsNothing);

    await tester.tap(find.text(l10n.trainersEmptyAction));
    await tester.pumpAndSettle();

    expect(find.text('invite-screen'), findsOneWidget);
  });

  testWidgets('ошибка первой загрузки: сообщение и «Повторить» грузит снова', (
    tester,
  ) async {
    repository.trainersFailure = const WorkoutNetworkFailure();

    final l10n = await pumpHome(tester);

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n.errorNetwork), findsOneWidget);
    expect(find.byType(TrainerCard), findsNothing);

    repository.trainersFailure = null;
    await tester.tap(find.text(l10n.retryAction));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Aziz Geidar'), findsOneWidget);
    expect(repository.trainersCalls, 2);
  });

  testWidgets('сырой текст ошибки не показывается', (tester) async {
    repository.trainersFailure = const WorkoutUnknownFailure();

    final l10n = await pumpHome(tester);

    expect(find.text(l10n.errorUnknown), findsOneWidget);
  });

  testWidgets('pull-to-refresh: запрос уходит ещё раз, список обновляется', (
    tester,
  ) async {
    await pumpHome(tester);
    repository.trainersResult = [
      aziz,
      const LinkedTrainer(trainerId: 't-2', trainerDisplayName: 'Новый'),
    ];

    await pullToRefresh(tester);

    expect(repository.trainersCalls, 2);
    expect(find.text('Новый'), findsOneWidget);
    expect(find.byType(TrainerCard), findsNWidgets(2));
  });

  testWidgets('индикатор не прячется, пока кубит не закончил refresh (Android)', (
    tester,
  ) async {
    await pumpHome(tester);
    repository.trainersGate = Completer<void>();

    await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(repository.trainersCalls, 2);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    repository.trainersGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  group('iOS: родной pull-to-refresh', () {
    testWidgets('в дереве CupertinoSliverRefreshControl, а не RefreshIndicator', (
      tester,
    ) async {
      await pumpHome(tester, platform: TargetPlatform.iOS);

      expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.text('Aziz Geidar'), findsOneWidget);
    });

    testWidgets('короткий список (одна карточка): pull вызывает refresh', (
      tester,
    ) async {
      await pumpHome(tester, platform: TargetPlatform.iOS);
      repository.trainersGate = Completer<void>();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.trainersCalls, 2);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      repository.trainersGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.text('Aziz Geidar'), findsOneWidget);
    });

    testWidgets('пустое состояние: pull обновляет, кнопка приглашения работает', (
      tester,
    ) async {
      repository.trainersResult = const [];
      final l10n = await pumpHome(tester, platform: TargetPlatform.iOS);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(repository.trainersCalls, 2);

      await tester.tap(find.text(l10n.trainersEmptyAction));
      await tester.pumpAndSettle();
      expect(find.text('invite-screen'), findsOneWidget);
    });

    testWidgets('ошибка обновления: индикатор уходит, снекбар, список цел', (
      tester,
    ) async {
      final l10n = await pumpHome(tester, platform: TargetPlatform.iOS);
      repository.trainersFailure = const WorkoutNetworkFailure();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.text(l10n.errorNetwork), findsOneWidget);
      expect(find.text('Aziz Geidar'), findsOneWidget);
    });
  });

  testWidgets('ошибка обновления: список остаётся, снекбар каждый раз', (
    tester,
  ) async {
    final l10n = await pumpHome(tester);
    repository.trainersFailure = const WorkoutServerUnavailableFailure();

    await pullToRefresh(tester);

    expect(find.text('Aziz Geidar'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text(l10n.errorServerUnavailable), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(HomeScreen))).clearSnackBars();
    await tester.pumpAndSettle();
    expect(find.text(l10n.errorServerUnavailable), findsNothing);

    await pullToRefresh(tester);

    expect(find.text(l10n.errorServerUnavailable), findsOneWidget);
    expect(find.text('Aziz Geidar'), findsOneWidget);
  });

  testWidgets('значок профиля ведёт на профиль', (tester) async {
    final l10n = await pumpHome(tester);

    await tester.tap(find.byTooltip(l10n.profileOpenAction));
    await tester.pumpAndSettle();

    expect(find.text('profile-screen'), findsOneWidget);
  });

  testWidgets('карточка пока не нажимается (экран программы — следующий шаг)', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byType(TrainerCard));
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, RouteNames.home);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  group('вёрстка', () {
    for (final entry in {
      'светлая': AppTheme.light,
      'тёмная': AppTheme.dark,
    }.entries) {
      for (final locale in const [Locale('ru'), Locale('en')]) {
        testWidgets(
          '${entry.key}, ${locale.languageCode}: 320 px, шрифт ×2, длинное имя',
          (tester) async {
            repository.trainersResult = [
              LinkedTrainer(
                trainerId: 't-1',
                trainerDisplayName: 'Очень Длинное Имя Тренера ' * 6,
              ),
              aziz,
            ];

            await pumpHome(
              tester,
              locale: locale,
              theme: entry.value,
              size: const Size(320, 640),
              textScale: 2,
            );

            expect(tester.takeException(), isNull);
            expect(find.byType(TrainerCard), findsNWidgets(2));
          },
        );

        testWidgets(
          '${entry.key}, ${locale.languageCode}: пустое состояние при шрифте ×2',
          (tester) async {
            repository.trainersResult = const [];

            await pumpHome(
              tester,
              locale: locale,
              theme: entry.value,
              size: const Size(320, 480),
              textScale: 2,
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('скелетон при шрифте ×2 не переполняется', (tester) async {
      repository.trainersGate = Completer<void>();

      await pumpHome(
        tester,
        size: const Size(320, 480),
        textScale: 2,
        settle: false,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
