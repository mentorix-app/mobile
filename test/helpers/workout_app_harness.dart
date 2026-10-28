import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/features/workout/domain/usecases/complete_workout_day.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/completion_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/screens/complete_day_screen.dart';
import 'package:mentorix_app/features/workout/presentation/screens/day_screen.dart';
import 'package:mentorix_app/features/workout/presentation/screens/program_screen.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/program_scope.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

import 'workout_fakes.dart';

/// Роутер, `ProgramCubit` и реальные экраны программы и дня под тем же
/// `ShellRoute`, что и в приложении. Фейковый репозиторий подставляется в GetIt
/// на время теста.
class WorkoutAppHarness {
  WorkoutAppHarness(this.repository) {
    GetIt.I.registerFactoryParam<ProgramCubit, String, void>(
      (trainerId, _) => ProgramCubit(trainerId, repository),
    );
    GetIt.I.registerFactoryParam<CompletionCubit, ProgramCubit, String>(
      (program, dayKey) => CompletionCubit(
        program: program,
        dayKey: dayKey,
        completeDay: CompleteWorkoutDay(repository),
      ),
    );
  }

  final FakeWorkoutRepository repository;

  late GoRouter router;

  /// Очистка GetIt: вызывать в `tearDown`.
  Future<void> dispose() => GetIt.I.reset();

  /// Запускает приложение. [initialPath] по умолчанию — программа [trainerId];
  /// [fromHome] — сначала «главный экран», потом `push`, как по нажатию на
  /// карточку тренера (так под экраном есть куда возвращаться).
  Future<AppLocalizations> pump(
    WidgetTester tester, {
    String trainerId = 'aziz',
    String? initialPath,
    bool fromHome = false,
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

    final path = initialPath ?? RouteNames.trainerProgramPath(trainerId);

    router = GoRouter(
      initialLocation: fromHome ? RouteNames.home : path,
      routes: [
        GoRoute(
          path: RouteNames.home,
          builder: (_, _) => const Scaffold(body: Text('home-screen')),
        ),
        ShellRoute(
          builder: (context, state, child) => ProgramScope(
            trainerId: state.pathParameters['trainerId']!,
            child: child,
          ),
          routes: [
            GoRoute(
              path: RouteNames.trainerProgram,
              builder: (_, _) => const ProgramScreen(),
            ),
            GoRoute(
              path: RouteNames.workoutDay,
              builder: (_, state) => DayScreen(
                trainerId: state.pathParameters['trainerId']!,
                dayKey: state.pathParameters['dayKey']!,
              ),
            ),
            GoRoute(
              path: RouteNames.completeDay,
              builder: (_, state) => CompleteDayScreen(
                trainerId: state.pathParameters['trainerId']!,
                dayKey: state.pathParameters['dayKey']!,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
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
    );
    if (fromHome) {
      await tester.pumpAndSettle();
      router.push(path);
    }
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Навигация начинается на следующем кадре, переход — ещё на одном.
      await tester.pump();
      if (fromHome) await tester.pump(const Duration(milliseconds: 100));
    }
    return lookupAppLocalizations(locale);
  }
}
