import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/config/telegram_config.dart';
import 'package:mentorix_app/core/logging/app_talker.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/app_router.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/core/widgets/brand_svg_icon.dart';
import 'package:mentorix_app/core/widgets/debug_logs_entry.dart';
import 'package:mentorix_app/generated/assets.dart';
import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/account_deletion_cubit.dart';
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
import 'package:mentorix_app/features/mode/presentation/cubit/dashboard_link_cubit.dart';
import 'package:mentorix_app/features/mode/presentation/screens/admin_web_only_screen.dart';
import 'package:mentorix_app/features/mode/presentation/screens/trainer_web_only_screen.dart';
import 'package:mentorix_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:mentorix_app/features/theme/presentation/widgets/theme_mode_button.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'helpers/auth_fakes.dart';
import 'helpers/fake_external_link_launcher.dart';
import 'helpers/talker_capture.dart';

class _Harness {
  _Harness({
    required this.context,
    required this.prefs,
    required this.repository,
    required this.session,
    required this.launcher,
  });

  final BuildContext context;
  final SharedPreferences prefs;
  final FakeAuthRepository repository;
  final SessionCubit session;
  final FakeExternalLinkLauncher launcher;

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
    String botName = 'mentorix_test_bot',
    String dashboardUrl = 'https://dashboard.test/trainer',
    bool appleAvailable = false,
    List<LinkedTrainer> trainers = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      ...stored,
      if (inviteDone) StorageKeys.onboardingInviteDone(profile.userId): true,
    });
    final prefs = await SharedPreferences.getInstance();

    final repository = FakeAuthRepository()
      ..profile = profile
      ..appleAvailable = appleAvailable
      ..trainers = trainers;
    final launcher = FakeExternalLinkLauncher();
    final session = SessionCubit(repository, SessionExpiredNotifier());
    switch (sessionState) {
      case _Session.unknown:
        break;
      case _Session.unauthenticated:
        await session.logout();
      case _Session.authenticated:
        await session.authenticate();
    }

    final flow = OnboardingFlow(prefs);
    GetIt.I
      ..registerFactory<LoginCubit>(() => LoginCubit(repository, session))
      ..registerFactory<TelegramLinkCubit>(
        () => TelegramLinkCubit(
          repository,
          session,
          flow,
          launcher,
          botName: botName,
        ),
      )
      ..registerFactory<InviteCubit>(
        () => InviteCubit(repository, session, flow),
      )
      ..registerFactory<DashboardLinkCubit>(
        () => DashboardLinkCubit(launcher, url: dashboardUrl),
      )
      ..registerFactory<AccountDeletionCubit>(
        () => AccountDeletionCubit(repository, session, flow),
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
      launcher: launcher,
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
        stored: {StorageKeys.themeMode: 'dark'},
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
      expect(app.prefs.getString(StorageKeys.themeMode), 'light');

      await tapButton();
      expect(find.byTooltip(app.l10n.themeModeDark), findsOneWidget);
      expect(currentBrightness(tester), Brightness.dark);

      await tapButton();
      expect(find.byTooltip(app.l10n.themeModeSystem), findsOneWidget);
      expect(app.prefs.getString(StorageKeys.themeMode), 'system');
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

    testWidgets('GET /client/trainers: пустой items → приглашение', (
      tester,
    ) async {
      await pumpApp(tester, inviteDone: false, trainers: const []);

      expect(find.byType(InviteScreen), findsOneWidget);
    });

    testWidgets('GET /client/trainers: тренер есть → приглашение пропущено', (
      tester,
    ) async {
      await pumpApp(
        tester,
        inviteDone: false,
        trainers: const [
          // Имя может прийти пустой строкой — на маршрут это не влияет.
          LinkedTrainer(trainerId: 'trainer-1', trainerDisplayName: ''),
        ],
      );

      expect(find.byType(InviteScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('тренер есть, но Telegram не привязан → сначала Telegram', (
      tester,
    ) async {
      await pumpApp(
        tester,
        profile: unlinkedProfile,
        inviteDone: false,
        trainers: const [testTrainer],
      );

      expect(find.byType(TelegramOfferScreen), findsOneWidget);
    });

    testWidgets('всё пройдено → главный экран', (tester) async {
      await pumpApp(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('сессия закончилась на главном → вход', (tester) async {
      final app = await pumpApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      // Выход — в профиле, с главного экрана туда ведёт отдельная кнопка.
      await tester.tap(find.text(app.l10n.profileOpenAction));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.tap(find.text(app.l10n.logoutAction));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(app.repository.logoutCalls, 1);
    });
  });

  group('профиль и удаление аккаунта', () {
    Future<_Harness> openProfile(WidgetTester tester) async {
      final app = await pumpApp(tester);
      await tester.tap(find.text(app.l10n.profileOpenAction));
      await tester.pumpAndSettle();
      return app;
    }

    Future<void> tapDelete(WidgetTester tester, _Harness app) async {
      await tester.tap(find.text(app.l10n.deleteAccountAction));
      await tester.pumpAndSettle();
    }

    Future<void> confirmDelete(WidgetTester tester, _Harness app) async {
      await tester.tap(find.text(app.l10n.deleteAccountConfirmAction));
      await tester.pumpAndSettle();
    }

    testWidgets('профиль открывается с главного: имя и почта', (tester) async {
      final app = await openProfile(tester);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text(testProfile.name), findsOneWidget);
      expect(find.text(testProfile.email), findsOneWidget);
      expect(find.text(app.l10n.logoutAction), findsOneWidget);
      expect(find.text(app.l10n.deleteAccountAction), findsOneWidget);
    });

    testWidgets('пустое имя — «Не указано», а не пустая строка', (tester) async {
      const nameless = UserProfile(
        userId: 'user-1',
        email: 'user@example.com',
        name: '',
        telegramLinked: true,
      );
      final app = await pumpApp(tester, profile: nameless);
      await tester.tap(find.text(app.l10n.profileOpenAction));
      await tester.pumpAndSettle();

      expect(find.text(app.l10n.profileValueEmpty), findsOneWidget);
    });

    testWidgets('диалог: что удалится и что восстановить нельзя', (tester) async {
      final app = await openProfile(tester);

      await tapDelete(tester, app);

      expect(find.text(app.l10n.deleteAccountDialogTitle), findsOneWidget);
      expect(find.text(app.l10n.deleteAccountDialogBody), findsOneWidget);
      expect(
        app.l10n.deleteAccountDialogBody,
        contains('cannot be restored'),
      );
      expect(app.repository.deleteCalls, isEmpty, reason: 'ещё не подтверждено');
    });

    testWidgets('«Отмена»: ничего не удалено, остаёмся в профиле', (
      tester,
    ) async {
      final app = await openProfile(tester);
      await tapDelete(tester, app);

      await tester.tap(find.text(app.l10n.cancelAction));
      await tester.pumpAndSettle();

      expect(app.repository.deleteCalls, isEmpty);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('подтверждение → удаление → экран входа', (tester) async {
      final app = await openProfile(tester);
      await tapDelete(tester, app);

      await confirmDelete(tester, app);

      expect(app.repository.deleteCalls, [false]);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
    });

    // Тексты по ответам бэкенда (docs/auth_api.md, часть 3).
    final failures = <String, (AuthFailure, String Function(AppLocalizations))>{
      '401/400 отказ Apple': (
        const AppleProofRejectedFailure(),
        (l) => l.errorAppleConfirmationRetry,
      ),
      '403 другой Apple ID': (
        const AppleAccountMismatchFailure(),
        (l) => l.errorAppleAccountMismatch,
      ),
      '409 в поддержку': (
        const AccountDeletionUnavailableFailure(),
        (l) => l.errorAccountDeletionUnavailable,
      ),
      '502/503 позже': (
        const AccountDeletionFailedFailure(),
        (l) => l.errorAccountDeletionFailed,
      ),
    };

    for (final entry in failures.entries) {
      testWidgets('${entry.key}: сообщение, аккаунт не удалён', (tester) async {
        final app = await openProfile(tester);
        app.repository.deleteFailure = entry.value.$1;

        await tapDelete(tester, app);
        await confirmDelete(tester, app);

        expect(find.text(entry.value.$2(app.l10n)), findsOneWidget);
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      });
    }

    testWidgets('отказ Apple: «Повторить» снова открывает окно Apple', (
      tester,
    ) async {
      final app = await openProfile(tester);
      app.repository.deleteFailure = const AppleProofRejectedFailure();
      await tapDelete(tester, app);
      await confirmDelete(tester, app);

      app.repository.deleteFailure = null;
      await tester.tap(find.text(app.l10n.retryAction));
      await tester.pumpAndSettle();

      expect(app.repository.deleteCalls, [false, true]);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('debug: на экране рядом с текстом статус и code', (tester) async {
      final app = await openProfile(tester);
      app.repository.deleteFailure = const AccountDeletionFailedFailure(
        details: ApiErrorDetails(status: 503, code: 'provider_not_configured'),
      );

      await tapDelete(tester, app);
      await confirmDelete(tester, app);

      expect(
        find.text(
          '${app.l10n.errorAccountDeletionFailed} '
          '(503 provider_not_configured)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('release: на экране только обычный текст', (tester) async {
      DebugLog.debugModeOverride = false;
      addTearDown(() => DebugLog.debugModeOverride = null);

      final app = await openProfile(tester);
      app.repository.deleteFailure = const AccountDeletionFailedFailure(
        details: ApiErrorDetails(status: 503, code: 'provider_not_configured'),
      );

      await tapDelete(tester, app);
      await confirmDelete(tester, app);

      expect(find.text(app.l10n.errorAccountDeletionFailed), findsOneWidget);
      expect(find.textContaining('provider_not_configured'), findsNothing);
      expect(find.textContaining('503'), findsNothing);
    });

    testWidgets('debug: долгое нажатие на заголовок открывает логи', (
      tester,
    ) async {
      resetTalker();
      final app = await openProfile(tester);
      expect(find.byType(TalkerScreen), findsNothing);

      await tester.longPress(find.text(app.l10n.profileTitle));
      await tester.pumpAndSettle();

      expect(find.byType(TalkerScreen), findsOneWidget);
    });

    testWidgets('обычное нажатие на заголовок логи не открывает', (
      tester,
    ) async {
      resetTalker();
      final app = await openProfile(tester);

      await tester.tap(find.text(app.l10n.profileTitle));
      await tester.pumpAndSettle();

      expect(find.byType(TalkerScreen), findsNothing);
    });

    testWidgets('release: долгое нажатие ничего не открывает, Talker нет', (
      tester,
    ) async {
      resetTalker();
      DebugLog.debugModeOverride = false;
      addTearDown(() => DebugLog.debugModeOverride = null);

      final app = await openProfile(tester);
      await tester.longPress(find.text(app.l10n.profileTitle));
      await tester.pumpAndSettle();

      expect(find.byType(TalkerScreen), findsNothing);
      expect(find.byType(DebugLogsEntry), findsOneWidget);
      expect(find.byType(GestureDetector).evaluate().where((e) {
        final w = e.widget as GestureDetector;
        return w.onLongPress != null;
      }), isEmpty);
      expect(AppTalker.isCreated, isFalse);
    });

    testWidgets('«Повторить» есть только у отказов Apple', (tester) async {
      final app = await openProfile(tester);
      app.repository.deleteFailure = const AccountDeletionUnavailableFailure();

      await tapDelete(tester, app);
      await confirmDelete(tester, app);

      expect(find.text(app.l10n.retryAction), findsNothing);
    });

    testWidgets('окно Apple закрыто: сообщения об ошибке нет', (tester) async {
      final app = await openProfile(tester);
      app.repository.deleteFailure = const SocialSignInCancelledFailure();

      await tapDelete(tester, app);
      await confirmDelete(tester, app);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text(app.l10n.errorUnknown), findsNothing);
      expect(find.text(app.l10n.errorAppleConfirmationRetry), findsNothing);
    });

    testWidgets('сообщение появляется ниже кнопок и ничего не сдвигает', (
      tester,
    ) async {
      final app = await openProfile(tester);
      final logout = find.text(app.l10n.logoutAction);
      final delete = find.text(app.l10n.deleteAccountAction);
      final before = [tester.getTopLeft(logout), tester.getTopLeft(delete)];

      app.repository.deleteFailure = const AccountDeletionFailedFailure();
      await tapDelete(tester, app);
      await confirmDelete(tester, app);

      expect(tester.getTopLeft(logout), before[0]);
      expect(tester.getTopLeft(delete), before[1]);
    });
  });

  group('иконки брендов на кнопках', () {
    // Telegram — Font Awesome, Google и Apple — SVG из assets/icons.
    Finder brandIcon(FaIconData icon) => find.byWidgetPredicate(
      (widget) => widget is FaIcon && widget.icon == icon.data,
    );

    Finder svgIcon(String asset) => find.byWidgetPredicate(
      (widget) => widget is BrandSvgIcon && widget.asset == asset,
    );

    testWidgets('вход: Google и Apple рядом с названием', (tester) async {
      final app = await pumpApp(
        tester,
        sessionState: _Session.unauthenticated,
        appleAvailable: true,
      );

      expect(svgIcon(Assets.iconsGoogle), findsOneWidget);
      expect(svgIcon(Assets.iconsApple), findsOneWidget);
      expect(find.text(app.l10n.signInWithGoogle), findsOneWidget);
      expect(find.text(app.l10n.signInWithApple), findsOneWidget);
    });

    testWidgets('Google не настроен: в debug пользователь видит, как запустить', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        sessionState: _Session.unauthenticated,
      );
      app.repository.signInFailure = const SocialSignInNotConfiguredFailure();

      await tester.tap(find.text(app.l10n.signInWithGoogle));
      await tester.pumpAndSettle();

      // kDebugMode в тестах включён: показывается подсказка запуска, а не
      // общее «способ недоступен».
      expect(find.text(app.l10n.errorGoogleNotConfigured), findsOneWidget);
      expect(find.text(app.l10n.errorSocialUnavailable), findsNothing);
    });

    testWidgets('Google — цветной логотип без перекраски, Apple — в цвет кнопки', (
      tester,
    ) async {
      await pumpApp(
        tester,
        sessionState: _Session.unauthenticated,
        appleAvailable: true,
      );

      final google = tester.widget<BrandSvgIcon>(svgIcon(Assets.iconsGoogle));
      final apple = tester.widget<BrandSvgIcon>(svgIcon(Assets.iconsApple));

      expect(google.tinted, isFalse, reason: 'правила Google: только цветной G');
      expect(apple.tinted, isTrue, reason: 'в файле Apple белый, а кнопка светлая');
    });

    testWidgets('вход без Apple (Android): иконки Apple нет', (tester) async {
      await pumpApp(tester, sessionState: _Session.unauthenticated);

      expect(svgIcon(Assets.iconsGoogle), findsOneWidget);
      expect(svgIcon(Assets.iconsApple), findsNothing);
    });

    testWidgets('экран входа объясняет, как войти, если занимались в Telegram', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        sessionState: _Session.unauthenticated,
      );

      // Входа через Telegram в API нет — вместо кнопки подсказка.
      expect(find.text(app.l10n.loginTelegramHint), findsOneWidget);
      expect(brandIcon(FontAwesomeIcons.telegram), findsNothing);
    });

    testWidgets('предложение привязать Telegram: иконка на кнопке', (
      tester,
    ) async {
      await pumpApp(tester, profile: unlinkedProfile, inviteDone: false);

      expect(brandIcon(FontAwesomeIcons.telegram), findsOneWidget);
    });

    testWidgets('ввод кода: иконка на кнопке «Открыть бота»', (tester) async {
      final app = await pumpApp(
        tester,
        profile: unlinkedProfile,
        inviteDone: false,
      );
      await tester.tap(find.text(app.l10n.telegramLinkAction));
      await tester.pumpAndSettle();

      expect(brandIcon(FontAwesomeIcons.telegram), findsOneWidget);
    });
  });

  group('режим по ролям из /auth/me', () {
    // Профиль, который онбординг отправил бы на Telegram и приглашение: тренер
    // и администратор его проходить не должны.
    UserProfile unfinished(List<String> roles) =>
        unlinkedProfileWithRoles(roles);

    GoRouter routerOf(WidgetTester tester) =>
        GoRouter.of(tester.element(find.byType(Scaffold).first));

    Future<void> openProfileFrom(WidgetTester tester, _Harness app) async {
      await tester.tap(find.text(app.l10n.profileOpenAction));
      await tester.pumpAndSettle();
    }

    Future<void> tryDeleteAccount(WidgetTester tester, _Harness app) async {
      app.repository.deleteFailure = const AccountDeletionUnavailableFailure();
      await tester.tap(find.text(app.l10n.deleteAccountAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(app.l10n.deleteAccountConfirmAction));
      await tester.pumpAndSettle();
    }

    group('client', () {
      testWidgets('клиентский поток: онбординг, затем главный экран', (
        tester,
      ) async {
        await pumpApp(
          tester,
          profile: unfinished(['client']),
          inviteDone: false,
        );

        expect(find.byType(TelegramOfferScreen), findsOneWidget);
        expect(find.byType(TrainerWebOnlyScreen), findsNothing);
        expect(find.byType(AdminWebOnlyScreen), findsNothing);
      });

      testWidgets('онбординг пройден → главный экран', (tester) async {
        await pumpApp(tester, profile: profileWithRoles(['client']));

        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('экраны тренера и администратора клиенту недоступны', (
        tester,
      ) async {
        await pumpApp(tester, profile: profileWithRoles(['client']));

        routerOf(tester).go(RouteNames.trainerWebOnly);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);

        routerOf(tester).go(RouteNames.adminWebOnly);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('роли в ответе нет → тоже клиентский поток', (tester) async {
        await pumpApp(tester, profile: testProfile);

        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    group('client + trainer', () {
      testWidgets('пока клиентский поток, экрана тренера нет', (tester) async {
        final app = await pumpApp(
          tester,
          profile: unfinished(['client', 'trainer']),
          inviteDone: false,
        );

        expect(find.byType(TelegramOfferScreen), findsOneWidget);
        expect(find.byType(TrainerWebOnlyScreen), findsNothing);
        expect(app.repository.trainersCalls, 1);
      });

      testWidgets('главный экран клиента, переключателя режимов нет', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['client', 'trainer']),
        );

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text(app.l10n.trainerOpenDashboardAction), findsNothing);
      });
    });

    group('trainer', () {
      testWidgets('экран «пока в веб-кабинете» вместо онбординга', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          profile: unfinished(['trainer']),
          inviteDone: false,
        );

        expect(find.byType(TrainerWebOnlyScreen), findsOneWidget);
        expect(find.text(app.l10n.trainerWebOnlyTitle), findsOneWidget);
        expect(find.byType(TelegramOfferScreen), findsNothing);
        expect(find.byType(InviteScreen), findsNothing);
        expect(find.byType(HomeScreen), findsNothing);
        expect(app.repository.trainersCalls, 0);
      });

      testWidgets('русский текст экрана', (tester) async {
        final app = await pumpApp(
          tester,
          locale: const Locale('ru'),
          profile: profileWithRoles(['trainer']),
        );

        expect(
          find.text('Тренерские инструменты пока в веб-кабинете'),
          findsOneWidget,
        );
        expect(app.l10n.trainerOpenDashboardAction, 'Открыть дашборд');
      });

      testWidgets('главный и чужие экраны ведут обратно на экран тренера', (
        tester,
      ) async {
        await pumpApp(tester, profile: profileWithRoles(['trainer']));

        for (final route in [
          RouteNames.home,
          RouteNames.telegramOffer,
          RouteNames.invite,
          RouteNames.adminWebOnly,
        ]) {
          routerOf(tester).go(route);
          await tester.pumpAndSettle();
          expect(
            find.byType(TrainerWebOnlyScreen),
            findsOneWidget,
            reason: route,
          );
        }
      });

      testWidgets('«Открыть дашборд» открывает адрес из конфига', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['trainer']),
        );

        await tester.tap(find.text(app.l10n.trainerOpenDashboardAction));
        await tester.pumpAndSettle();

        expect(app.launcher.opened, [Uri.parse('https://dashboard.test/trainer')]);
      });

      testWidgets('адрес из config/stage.json: кнопка активна и открывает его', (
        tester,
      ) async {
        final stage =
            jsonDecode(File('config/stage.json').readAsStringSync())
                as Map<String, dynamic>;
        final url = stage['DASHBOARD_URL'] as String;
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['trainer']),
          dashboardUrl: url,
        );

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, app.l10n.trainerOpenDashboardAction),
        );
        expect(button.onPressed, isNotNull);

        await tester.tap(find.text(app.l10n.trainerOpenDashboardAction));
        await tester.pumpAndSettle();
        expect(app.launcher.opened, [Uri.parse(url)]);
      });

      testWidgets('браузер не открылся — сообщение об ошибке', (tester) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['trainer']),
        );
        app.launcher.result = false;

        await tester.tap(find.text(app.l10n.trainerOpenDashboardAction));
        await tester.pumpAndSettle();

        expect(find.text(app.l10n.errorOpenDashboard), findsOneWidget);
      });

      testWidgets('адрес — плейсхолдер: кнопка неактивна, ничего не открывается', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['trainer']),
          dashboardUrl: 'YOUR_DASHBOARD_URL',
        );

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, app.l10n.trainerOpenDashboardAction),
        );
        expect(button.onPressed, isNull);
        expect(app.launcher.opened, isEmpty);
      });

      testWidgets('профиль с выходом', (tester) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['trainer']),
        );
        await openProfileFrom(tester, app);

        expect(find.byType(ProfileScreen), findsOneWidget);
        await tester.tap(find.text(app.l10n.logoutAction));
        await tester.pumpAndSettle();

        expect(app.repository.logoutCalls, 1);
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('удаление: 409 → «обратитесь в поддержку», сессия цела', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['trainer']),
        );
        await openProfileFrom(tester, app);

        await tryDeleteAccount(tester, app);

        expect(app.repository.deleteCalls, [false]);
        expect(find.text(app.l10n.errorAccountDeletionUnavailable), findsOneWidget);
        expect(app.l10n.errorAccountDeletionUnavailable, contains('contact support'));
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      });

      testWidgets('русский текст отказа в удалении', (tester) async {
        final app = await pumpApp(
          tester,
          locale: const Locale('ru'),
          profile: profileWithRoles(['trainer']),
        );
        await openProfileFrom(tester, app);

        await tryDeleteAccount(tester, app);

        expect(find.textContaining('Обратитесь в поддержку'), findsOneWidget);
      });
    });

    group('admin', () {
      testWidgets('экран «только в веб-кабинете» вместо онбординга', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          profile: unfinished(['admin']),
          inviteDone: false,
        );

        expect(find.byType(AdminWebOnlyScreen), findsOneWidget);
        expect(find.text(app.l10n.adminWebOnlyTitle), findsOneWidget);
        expect(find.byType(TelegramOfferScreen), findsNothing);
        expect(find.byType(InviteScreen), findsNothing);
        expect(find.byType(HomeScreen), findsNothing);
        expect(app.repository.trainersCalls, 0);
      });

      testWidgets('русский текст экрана', (tester) async {
        await pumpApp(
          tester,
          locale: const Locale('ru'),
          profile: profileWithRoles(['admin']),
        );

        expect(
          find.text('Администрирование доступно только в веб-кабинете'),
          findsOneWidget,
        );
      });

      testWidgets('кнопки дашборда у администратора нет', (tester) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['admin']),
        );

        expect(find.text(app.l10n.trainerOpenDashboardAction), findsNothing);
      });

      testWidgets('другие экраны ведут обратно на экран администратора', (
        tester,
      ) async {
        await pumpApp(tester, profile: profileWithRoles(['admin']));

        for (final route in [
          RouteNames.home,
          RouteNames.invite,
          RouteNames.trainerWebOnly,
        ]) {
          routerOf(tester).go(route);
          await tester.pumpAndSettle();
          expect(
            find.byType(AdminWebOnlyScreen),
            findsOneWidget,
            reason: route,
          );
        }
      });

      testWidgets('«Выйти» на самом экране', (tester) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['admin']),
        );

        await tester.tap(find.text(app.l10n.logoutAction));
        await tester.pumpAndSettle();

        expect(app.repository.logoutCalls, 1);
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('удаление: 409 → «обратитесь в поддержку»', (tester) async {
        final app = await pumpApp(
          tester,
          profile: profileWithRoles(['admin']),
        );
        await openProfileFrom(tester, app);

        await tryDeleteAccount(tester, app);

        expect(find.text(app.l10n.errorAccountDeletionUnavailable), findsOneWidget);
        expect(find.byType(ProfileScreen), findsOneWidget);
      });
    });

    testWidgets('вход тренера: режим берётся из ролей, а не из входа', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        sessionState: _Session.unauthenticated,
        profile: unfinished(['trainer']),
        inviteDone: false,
      );
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.tap(find.text(app.l10n.signInWithGoogle));
      await tester.pumpAndSettle();

      expect(find.byType(TrainerWebOnlyScreen), findsOneWidget);
      expect(find.byType(TelegramOfferScreen), findsNothing);
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

  group('код Telegram одноразовый', () {
    /// Открывает экран ввода кода (профиль без Telegram → предложение → код).
    Future<_Harness> openCodeScreen(
      WidgetTester tester, {
      String botName = 'mentorix_test_bot',
    }) async {
      final app = await pumpApp(
        tester,
        profile: unlinkedProfile,
        inviteDone: false,
        botName: botName,
      );
      await tester.tap(find.text(app.l10n.telegramLinkAction));
      await tester.pumpAndSettle();
      expect(find.byType(TelegramCodeScreen), findsOneWidget);
      return app;
    }

    Future<void> submitCode(WidgetTester tester, _Harness app) async {
      await tester.enterText(find.byType(TextField), 'ABCD1234');
      await tester.pump();
      await tester.tap(find.text(app.l10n.continueAction));
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    // Сервер ответил на код — он потрачен: поле очищается, подсказка + кнопка.
    final spent = <String, AuthFailure>{
      '400 — неверный, просрочен или использован':
          const TelegramCodeInvalidFailure(),
      '404 — учётной записи больше нет': const AccountNotFoundFailure(),
      '409 — нельзя объединить': const TelegramLinkConflictFailure(),
      '409 — уже привязан другой Telegram': const TelegramAlreadyLinkedFailure(),
      '503 — привязка недоступна': const ServerUnavailableFailure(),
      '5xx — прочая ошибка сервера': const UnknownFailure(),
    };

    for (final entry in spent.entries) {
      testWidgets('${entry.key}: поле очищено, подсказка и кнопка', (
        tester,
      ) async {
        final app = await openCodeScreen(tester);
        app.repository.linkFailure = entry.value;

        await submitCode(tester, app);

        expect(app.repository.linkedCodes, ['ABCD1234']);
        expect(fieldText(tester), isEmpty, reason: 'код потрачен');
        expect(find.text(app.l10n.telegramCodeSpentHint), findsOneWidget);
        expect(find.text(app.l10n.telegramOpenBotAction), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(
                  OutlinedButton,
                  app.l10n.telegramOpenBotAction,
                ),
              )
              .onPressed,
          isNotNull,
        );
      });
    }

    // Два вида 409 различаются кодом, а не текстом, и у каждого свой
    // локализованный текст; текст бэкенда не показывается.
    testWidgets('409 telegram_link_conflict: свой текст и подсказка', (
      tester,
    ) async {
      final app = await openCodeScreen(tester);
      app.repository.linkFailure = const TelegramLinkConflictFailure();

      await submitCode(tester, app);

      expect(find.text(app.l10n.errorTelegramConflict), findsOneWidget);
      expect(find.text(app.l10n.errorTelegramAlreadyLinked), findsNothing);
      expect(find.text(app.l10n.telegramCodeSpentHint), findsOneWidget);
      expect(fieldText(tester), isEmpty);
    });

    testWidgets('409 telegram_already_linked: свой текст и подсказка', (
      tester,
    ) async {
      final app = await openCodeScreen(tester);
      app.repository.linkFailure = const TelegramAlreadyLinkedFailure();

      await submitCode(tester, app);

      expect(find.text(app.l10n.errorTelegramAlreadyLinked), findsOneWidget);
      expect(find.text(app.l10n.errorTelegramConflict), findsNothing);
      expect(find.text(app.l10n.telegramCodeSpentHint), findsOneWidget);
    });

    // Код ещё действует: поле остаётся, подсказки «получите новый» нет.
    final alive = <String, AuthFailure>{
      '429 — слишком много попыток': const TooManyRequestsFailure(),
      '401 — сессия закончилась': const SessionExpiredFailure(),
      'нет связи — ответа сервера не было': const NetworkFailure(),
    };

    for (final entry in alive.entries) {
      testWidgets('${entry.key}: поле не очищается', (tester) async {
        final app = await openCodeScreen(tester);
        app.repository.linkFailure = entry.value;

        await submitCode(tester, app);

        expect(fieldText(tester), 'ABCD1234', reason: 'код ещё действует');
        expect(find.text(app.l10n.telegramCodeSpentHint), findsNothing);
      });
    }

    testWidgets('429: ошибка в снекбаре, повтор не отправляется сам', (
      tester,
    ) async {
      final app = await openCodeScreen(tester);
      app.repository.linkFailure = const TooManyRequestsFailure();

      await submitCode(tester, app);

      expect(find.text(app.l10n.errorTooManyRequests), findsOneWidget);
      expect(app.repository.linkedCodes, hasLength(1));
    });

    testWidgets('подсказка исчезает, когда вводят новый код', (tester) async {
      final app = await openCodeScreen(tester);
      app.repository.linkFailure = const TelegramCodeInvalidFailure();
      await submitCode(tester, app);
      expect(find.text(app.l10n.telegramCodeSpentHint), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'N');
      await tester.pump();

      expect(find.text(app.l10n.telegramCodeSpentHint), findsNothing);
    });

    testWidgets('«Открыть бота» открывает https://t.me/<bot>?start=link', (
      tester,
    ) async {
      final app = await openCodeScreen(tester);

      await tester.tap(find.text(app.l10n.telegramOpenBotAction));
      await tester.pumpAndSettle();

      expect(app.launcher.opened.single.toString(),
          'https://t.me/mentorix_test_bot?start=link');
    });

    testWidgets('бот не открылся — сообщение об ошибке', (tester) async {
      final app = await openCodeScreen(tester);
      app.launcher.result = false;

      await tester.tap(find.text(app.l10n.telegramOpenBotAction));
      await tester.pumpAndSettle();

      expect(find.text(app.l10n.errorOpenTelegram), findsOneWidget);
    });

    testWidgets('имя бота — плейсхолдер: кнопка неактивна', (tester) async {
      final app = await openCodeScreen(
        tester,
        botName: TelegramConfig.botNamePlaceholder,
      );

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, app.l10n.telegramOpenBotAction),
      );

      expect(button.onPressed, isNull);
      expect(app.launcher.opened, isEmpty);
    });

    testWidgets('на экране три шага инструкции', (tester) async {
      final app = await openCodeScreen(tester);

      expect(find.text(app.l10n.telegramStep1), findsOneWidget);
      expect(find.text(app.l10n.telegramStep2), findsOneWidget);
      expect(find.text(app.l10n.telegramStep3), findsOneWidget);
    });
  });
}
