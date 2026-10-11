import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/app_router.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/invite_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/screens/invite_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/telegram_code_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/telegram_offer_screen.dart';
import 'package:mentorix_app/features/home/presentation/screens/home_screen.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:mentorix_app/features/theme/presentation/widgets/theme_mode_button.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_fakes.dart';

class _Harness {
  _Harness({
    required this.context,
    required this.prefs,
    required this.repository,
    required this.session,
  });

  final BuildContext context;
  final SharedPreferences prefs;
  final FakeAuthRepository repository;
  final SessionCubit session;

  AppLocalizations get l10n => AppLocalizations.of(context);
}

enum _Session { unknown, unauthenticated, authenticated }

void main() {
  tearDown(() async {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
    await GetIt.I.reset();
  });

  /// Собирает приложение целиком (роутер, сессия, тема) на фейковом
  /// репозитории. По умолчанию — вошедший пользователь, прошедший онбординг.
  Future<_Harness> pumpApp(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    Map<String, Object> stored = const {},
    _Session sessionState = _Session.authenticated,
    UserProfile profile = testProfile,
    bool inviteDone = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      ...stored,
      if (inviteDone) 'onboarding_invite_done_${profile.userId}': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final repository = FakeAuthRepository()..profile = profile;
    final session = SessionCubit(repository, SessionExpiredNotifier());
    switch (sessionState) {
      case _Session.unknown:
        break;
      case _Session.unauthenticated:
        await session.logout();
      case _Session.authenticated:
        session.setAuthenticated(profile);
    }

    final flow = OnboardingFlow(prefs);
    GetIt.I
      ..registerFactory<LoginCubit>(() => LoginCubit(repository, session))
      ..registerFactory<TelegramLinkCubit>(
        () => TelegramLinkCubit(repository, session, flow),
      )
      ..registerFactory<InviteCubit>(
        () => InviteCubit(repository, session, flow),
      );

    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    tester.platformDispatcher.localesTestValue = [locale];

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>(
            create: (_) => ThemeCubit(ThemeRepositoryImpl(prefs)),
          ),
          BlocProvider<SessionCubit>.value(value: session),
        ],
        child: MentorixApp(
          router: createAppRouter(session: session, flow: flow),
        ),
      ),
    );
    await tester.pumpAndSettle();

    addTearDown(session.close);

    final context = tester.element(find.byType(Scaffold).first);
    return _Harness(
      context: context,
      prefs: prefs,
      repository: repository,
      session: session,
    );
  }

  Brightness currentBrightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

  group('сборка приложения', () {
    for (final brightness in Brightness.values) {
      for (final locale in const [Locale('ru'), Locale('en')]) {
        testWidgets(
          'главный экран собирается: ${brightness.name}, ${locale.languageCode}',
          (tester) async {
            final app = await pumpApp(
              tester,
              brightness: brightness,
              locale: locale,
            );

            expect(find.byType(HomeScreen), findsOneWidget);
            expect(Theme.of(app.context).brightness, brightness);
            expect(app.l10n.localeName, locale.languageCode);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('тема', () {
    testWidgets('по умолчанию следует за системной', (tester) async {
      await pumpApp(tester, brightness: Brightness.dark);

      expect(currentBrightness(tester), Brightness.dark);
    });

    testWidgets('сохранённый выбор применяется с первого кадра', (
      tester,
    ) async {
      await pumpApp(
        tester,
        brightness: Brightness.light,
        stored: {ThemeRepositoryImpl.storageKey: 'dark'},
      );

      expect(currentBrightness(tester), Brightness.dark);
    });

    testWidgets('кнопка проходит систему → светлую → тёмную → систему', (
      tester,
    ) async {
      // Системная тема — тёмная, чтобы «система» и «светлая» различались.
      final app = await pumpApp(tester, brightness: Brightness.dark);

      Future<void> tapButton() async {
        await tester.tap(find.byType(ThemeModeButton));
        await tester.pumpAndSettle();
      }

      expect(find.byTooltip(app.l10n.themeModeSystem), findsOneWidget);

      await tapButton();
      expect(find.byTooltip(app.l10n.themeModeLight), findsOneWidget);
      expect(currentBrightness(tester), Brightness.light);
      expect(app.prefs.getString(ThemeRepositoryImpl.storageKey), 'light');

      await tapButton();
      expect(find.byTooltip(app.l10n.themeModeDark), findsOneWidget);
      expect(currentBrightness(tester), Brightness.dark);

      await tapButton();
      expect(find.byTooltip(app.l10n.themeModeSystem), findsOneWidget);
      expect(app.prefs.getString(ThemeRepositoryImpl.storageKey), 'system');
    });
  });

  group('маршруты по состоянию сессии', () {
    testWidgets('сессия неизвестна → заставка', (tester) async {
      await pumpApp(tester, sessionState: _Session.unknown);

      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('нет сессии → вход', (tester) async {
      await pumpApp(tester, sessionState: _Session.unauthenticated);

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Telegram не привязан → предложение привязать', (
      tester,
    ) async {
      await pumpApp(tester, profile: unlinkedProfile, inviteDone: false);

      expect(find.byType(TelegramOfferScreen), findsOneWidget);
    });

    testWidgets('Telegram привязан, приглашения нет → приглашение', (
      tester,
    ) async {
      await pumpApp(tester, inviteDone: false);

      expect(find.byType(InviteScreen), findsOneWidget);
    });

    testWidgets('всё пройдено → главный экран', (tester) async {
      await pumpApp(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('сессия закончилась на главном → вход', (tester) async {
      final app = await pumpApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.text(app.l10n.logoutAction));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(app.repository.logoutCalls, 1);
    });
  });

  group('порядок после входа: Telegram → приглашение', () {
    testWidgets('пропуск Telegram ведёт к приглашению', (tester) async {
      final app = await pumpApp(
        tester,
        profile: unlinkedProfile,
        inviteDone: false,
      );

      await tester.tap(find.text(app.l10n.telegramSkipAction));
      await tester.pumpAndSettle();

      expect(find.byType(InviteScreen), findsOneWidget);
    });

    testWidgets('код Telegram: привязка → профиль заново → приглашение', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        profile: unlinkedProfile,
        inviteDone: false,
      );

      await tester.tap(find.text(app.l10n.telegramLinkAction));
      await tester.pumpAndSettle();
      expect(find.byType(TelegramCodeScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ABCD1234');
      await tester.pump();
      await tester.tap(find.text(app.l10n.continueAction));
      await tester.pumpAndSettle();

      expect(app.repository.linkedCodes, ['ABCD1234']);
      expect(find.byType(InviteScreen), findsOneWidget);
    });

    testWidgets('приглашение принято → главный экран', (tester) async {
      final app = await pumpApp(tester, inviteDone: false);

      await tester.enterText(find.byType(TextField), 'inv_abc123');
      await tester.pump();
      await tester.tap(find.text(app.l10n.inviteAcceptAction));
      await tester.pumpAndSettle();

      expect(app.repository.acceptedInvites, ['inv_abc123']);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('приглашение можно отложить', (tester) async {
      final app = await pumpApp(tester, inviteDone: false);

      await tester.tap(find.text(app.l10n.inviteSkipAction));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
