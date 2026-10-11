import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/telegram_config.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_external_link_launcher.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeExternalLinkLauncher launcher;
  late SessionCubit session;

  Future<TelegramLinkCubit> createCubit({
    String botName = 'mentorix_test_bot',
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    repository = FakeAuthRepository()..profile = unlinkedProfile;
    launcher = FakeExternalLinkLauncher();
    session = SessionCubit(repository, SessionExpiredNotifier())
      ..setAuthenticated(unlinkedProfile);

    return TelegramLinkCubit(
      repository,
      session,
      OnboardingFlow(prefs),
      launcher,
      botName: botName,
    );
  }

  tearDown(() async => session.close());

  group('код потрачен только ошибкой шага привязки', () {
    test('400 на коде: код потрачен', () async {
      final cubit = await createCubit();
      repository.linkFailure = const TelegramCodeInvalidFailure();

      await cubit.submit('ABCD1234');

      expect(
        cubit.state,
        const TelegramLinkFailed(
          TelegramCodeInvalidFailure(),
          codeSpent: true,
        ),
      );
      await cubit.close();
    });

    test('429 на коде: код ещё действует', () async {
      final cubit = await createCubit();
      repository.linkFailure = const TooManyRequestsFailure();

      await cubit.submit('ABCD1234');

      expect(
        cubit.state,
        const TelegramLinkFailed(TooManyRequestsFailure()),
      );
      await cubit.close();
    });

    test('профиль не получен уже после привязки: код не потрачен, '
        'повтор не отправляет его снова', () async {
      final cubit = await createCubit();
      repository.profileFailure = const NetworkFailure();

      await cubit.submit('ABCD1234');

      // Привязка прошла, упал /auth/me — это не «потраченный код».
      expect(cubit.state, const TelegramLinkFailed(NetworkFailure()));
      expect(repository.linkedCodes, ['ABCD1234']);

      repository.profileFailure = null;
      await cubit.submit('ABCD1234');

      expect(repository.linkedCodes, ['ABCD1234'], reason: 'код один раз');
      expect(cubit.state, const TelegramLinkSuccess());
      await cubit.close();
    });
  });

  group('«Открыть бота»', () {
    test('открывает https://t.me/<bot>?start=link', () async {
      final cubit = await createCubit();

      final opened = await cubit.openBot();

      expect(opened, isTrue);
      expect(
        launcher.opened.single.toString(),
        'https://t.me/mentorix_test_bot?start=link',
      );
      await cubit.close();
    });

    test('имя бота — плейсхолдер: не открывает и сообщает «не настроено»', () async {
      final cubit = await createCubit(
        botName: TelegramConfig.botNamePlaceholder,
      );

      expect(cubit.isBotConfigured, isFalse);
      expect(await cubit.openBot(), isFalse);
      expect(launcher.opened, isEmpty);
      await cubit.close();
    });

    test('ссылку открыть не удалось → false', () async {
      final cubit = await createCubit();
      launcher.result = false;

      expect(await cubit.openBot(), isFalse);
      await cubit.close();
    });
  });
}
