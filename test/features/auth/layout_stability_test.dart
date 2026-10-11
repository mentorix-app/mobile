import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/invite_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/screens/invite_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/telegram_code_screen.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_external_link_launcher.dart';

/// Элементы не должны «прыгать»: нажатие, ввод и клавиатура не двигают то,
/// на что пользователь смотрит и во что целится пальцем.
void main() {
  const screen = Size(402, 874);
  late FakeAuthRepository repository;
  late SessionCubit session;
  late OnboardingFlow flow;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    flow = OnboardingFlow(await SharedPreferences.getInstance());
    repository = FakeAuthRepository();
    session = SessionCubit(repository, SessionExpiredNotifier());
  });

  tearDown(() => session.close());

  Future<void> pumpScreen<C extends BlocBase<Object?>>(
    WidgetTester tester, {
    required Widget screenWidget,
    required C cubit,
    bool apple = true,
  }) async {
    repository.appleAvailable = apple;
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<C>.value(value: cubit, child: screenWidget),
      ),
    );
    await tester.pump();
  }

  Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

  group('экран входа', () {
    testWidgets('нажатие на кнопку не двигает кнопки и текст', (tester) async {
      await pumpScreen(
        tester,
        screenWidget: const LoginScreen(),
        cubit: LoginCubit(repository, session),
      );
      final google = find.byType(FilledButton);
      final apple = find.byType(OutlinedButton);
      final title = find.text('Sign in');

      final googleBefore = rectOf(tester, google);
      final appleBefore = rectOf(tester, apple);
      final titleBefore = rectOf(tester, title);

      repository.gate = Completer<void>(); // вход «висит» — экран в загрузке
      await tester.tap(google);
      await tester.pump();

      expect(
        find.byType(LinearProgressIndicator),
        findsOneWidget,
        reason: 'загрузка должна быть видна',
      );
      expect(rectOf(tester, google), googleBefore, reason: 'кнопка Google');
      expect(rectOf(tester, apple), appleBefore, reason: 'кнопка Apple');
      expect(rectOf(tester, title), titleBefore, reason: 'заголовок');

      repository.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('ошибка входа не двигает элементы', (tester) async {
      await pumpScreen(
        tester,
        screenWidget: const LoginScreen(),
        cubit: LoginCubit(repository, session),
      );
      final google = find.byType(FilledButton);
      final before = rectOf(tester, google);

      repository.signInFailure = const SocialTokenRejectedFailure();
      await tester.tap(google);
      await tester.pumpAndSettle();

      expect(rectOf(tester, google), before);
    });
  });

  group('ввод кода Telegram', () {
    TelegramLinkCubit linkCubit() => TelegramLinkCubit(
      repository,
      session,
      flow,
      FakeExternalLinkLauncher(),
      botName: 'mentorix_test_bot',
    );

    testWidgets('клавиатура не сдвигает поле и кнопки', (tester) async {
      await pumpScreen(
        tester,
        screenWidget: const TelegramCodeScreen(),
        cubit: linkCubit(),
      );
      final field = find.byType(TextField);
      final submit = find.byType(FilledButton);
      final fieldBefore = rectOf(tester, field);
      final submitBefore = rectOf(tester, submit);

      // Клавиатура 300 dp, как после нажатия на поле.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      expect(rectOf(tester, field), fieldBefore, reason: 'поле ввода');
      expect(rectOf(tester, submit), submitBefore, reason: 'кнопка «Продолжить»');
    });

    testWidgets('нажатие «Продолжить» не двигает поле', (tester) async {
      await pumpScreen(
        tester,
        screenWidget: const TelegramCodeScreen(),
        cubit: linkCubit(),
      );
      await tester.enterText(find.byType(TextField), 'ABCD1234');
      await tester.pump();
      final field = find.byType(TextField);
      final before = rectOf(tester, field);

      // Завершаем ошибкой: успех увёл бы на другой экран (нужен роутер).
      repository
        ..linkFailure = const NetworkFailure()
        ..gate = Completer<void>();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(rectOf(tester, field), before);

      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(rectOf(tester, field), before, reason: 'после ответа сервера');
    });

    testWidgets('сообщение о потраченном коде не двигает поле, '
        'а его исчезновение при вводе — тоже', (tester) async {
      await pumpScreen(
        tester,
        screenWidget: const TelegramCodeScreen(),
        cubit: linkCubit(),
      );
      final field = find.byType(TextField);
      final before = rectOf(tester, field);

      // Код потрачен: поле очищается, появляется сообщение.
      repository.linkFailure = const TelegramCodeInvalidFailure();
      await tester.enterText(field, 'ABCD1234');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The code was already used or has expired. '
          'Get a new one in the bot.',
        ),
        findsOneWidget,
      );
      expect(rectOf(tester, field), before, reason: 'при появлении сообщения');

      // Пользователь начинает вводить новый код: сообщение исчезает.
      await tester.enterText(field, 'N');
      await tester.pumpAndSettle();
      expect(rectOf(tester, field), before, reason: 'при начале ввода');
    });
  });

  group('приглашение', () {
    testWidgets('клавиатура не сдвигает поле и кнопки', (tester) async {
      await pumpScreen(
        tester,
        screenWidget: const InviteScreen(),
        cubit: InviteCubit(repository, session, flow),
      );
      final field = find.byType(TextField);
      final accept = find.byType(FilledButton);
      final fieldBefore = rectOf(tester, field);
      final acceptBefore = rectOf(tester, accept);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      expect(rectOf(tester, field), fieldBefore);
      expect(rectOf(tester, accept), acceptBefore);
    });

    testWidgets('нажатие «Принять» не двигает поле', (tester) async {
      await pumpScreen(
        tester,
        screenWidget: const InviteScreen(),
        cubit: InviteCubit(repository, session, flow),
      );
      await tester.enterText(find.byType(TextField), 'inv_abc');
      await tester.pump();
      final before = rectOf(tester, find.byType(TextField));

      repository
        ..inviteFailure = const InviteNotFoundFailure()
        ..gate = Completer<void>();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(rectOf(tester, find.byType(TextField)), before);

      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        rectOf(tester, find.byType(TextField)),
        before,
        reason: 'после ответа сервера',
      );
    });
  });
}
