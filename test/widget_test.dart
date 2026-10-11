import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/config/telegram_config.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/app_router.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/widgets/brand_svg_icon.dart';
import 'package:mentorix_app/generated/assets.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
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
import 'helpers/fake_external_link_launcher.dart';

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
    bool appleAvailable = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      ...stored,
      if (inviteDone) 'onboarding_invite_done_${profile.userId}': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final repository = FakeAuthRepository()
      ..profile = profile
      ..appleAvailable = appleAvailable;
    final launcher = FakeExternalLinkLauncher();
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

    testWidgets('409: текст из message показывается рядом с подсказкой', (
      tester,
    ) async {
      final app = await openCodeScreen(tester);
      app.repository.linkFailure = const TelegramLinkConflictFailure(
        message: 'telegram is already linked to another account',
      );

      await submitCode(tester, app);

      expect(
        find.text('telegram is already linked to another account'),
        findsOneWidget,
      );
      expect(find.text(app.l10n.telegramCodeSpentHint), findsOneWidget);
      expect(fieldText(tester), isEmpty);
    });

    testWidgets('409 без message: только локализованный текст и подсказка', (
      tester,
    ) async {
      final app = await openCodeScreen(tester);
      app.repository.linkFailure = const TelegramLinkConflictFailure();

      await submitCode(tester, app);

      expect(find.text(app.l10n.errorTelegramConflict), findsOneWidget);
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
