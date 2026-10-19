import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/features/auth/data/models/user_profile_model.dart';
import 'package:mentorix_app/features/auth/domain/entities/app_mode.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_fakes.dart';

/// Режим приложения задают роли из `/auth/me` (`docs/ARCHITECTURE.md`, раздел 5),
/// а не способ входа.
void main() {
  group('режим по ролям', () {
    final cases = <String, (List<String>, AppMode, List<AppMode>)>{
      'client': (['client'], AppMode.client, [AppMode.client]),
      'trainer': (['trainer'], AppMode.trainer, [AppMode.trainer]),
      'client + trainer': (
        ['client', 'trainer'],
        AppMode.client,
        [AppMode.client, AppMode.trainer],
      ),
      'порядок ролей не важен': (
        ['trainer', 'client'],
        AppMode.client,
        [AppMode.client, AppMode.trainer],
      ),
      'admin': (['admin'], AppMode.admin, [AppMode.admin]),
      'admin перебивает остальное': (
        ['admin', 'client', 'trainer'],
        AppMode.admin,
        [AppMode.admin],
      ),
      'ролей нет — клиентский режим': ([], AppMode.client, [AppMode.client]),
      'незнакомая роль — клиентский режим': (
        ['moderator'],
        AppMode.client,
        [AppMode.client],
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final (roles, mode, available) = entry.value;
        final profile = profileWithRoles(roles);

        expect(profile.mode, mode);
        expect(profile.availableModes, available);
      });
    }

    test('roles из JSON /auth/me → режим', () {
      UserProfileModel from(Object? roles) => UserProfileModel.fromJson({
        'user_id': 'u-1',
        'roles': roles,
      });

      expect(from(['trainer']).mode, AppMode.trainer);
      expect(from(['admin']).mode, AppMode.admin);
      expect(from(['client', 'trainer']).mode, AppMode.client);
      expect(from(null).mode, AppMode.client, reason: 'поля roles нет');
      expect(from('trainer').mode, AppMode.client, reason: 'не список');
    });
  });

  group('SessionCubit: GET /client/trainers только для клиента', () {
    late FakeAuthRepository repository;
    late SessionExpiredNotifier notifier;
    late SessionCubit cubit;

    setUp(() {
      repository = FakeAuthRepository()..trainers = const [testTrainer];
      notifier = SessionExpiredNotifier();
      cubit = SessionCubit(repository, notifier);
    });

    tearDown(() async {
      await cubit.close();
      await notifier.dispose();
    });

    Future<SessionAuthenticated> authenticateAs(List<String> roles) async {
      repository.profile = profileWithRoles(roles);
      await cubit.authenticate();
      return cubit.state as SessionAuthenticated;
    }

    test('client: запрос уходит, тренеры сохранены', () async {
      final state = await authenticateAs(['client']);

      expect(repository.trainersCalls, 1);
      expect(state.mode, AppMode.client);
      expect(state.hasTrainer, isTrue);
    });

    test('client + trainer: клиентский поток, запрос уходит', () async {
      final state = await authenticateAs(['client', 'trainer']);

      expect(repository.trainersCalls, 1);
      expect(state.mode, AppMode.client);
    });

    test('trainer: запрос не уходит', () async {
      final state = await authenticateAs(['trainer']);

      expect(repository.trainersCalls, 0);
      expect(state.mode, AppMode.trainer);
      expect(state.trainers, isEmpty);
    });

    test('admin: запрос не уходит', () async {
      final state = await authenticateAs(['admin']);

      expect(repository.trainersCalls, 0);
      expect(state.mode, AppMode.admin);
    });
  });

  group('OnboardingFlow: следующий экран по режиму', () {
    late OnboardingFlow flow;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      flow = OnboardingFlow(await SharedPreferences.getInstance());
    });

    /// Telegram не привязан и тренера нет: клиента это ведёт на онбординг.
    String next(List<String> roles) => flow.nextRoute(
      unlinkedProfileWithRoles(roles),
      hasTrainer: false,
    );

    test('client: Telegram не привязан → предложение', () {
      expect(next(['client']), RouteNames.telegramOffer);
    });

    test('client + trainer: тот же клиентский порядок', () {
      expect(next(['client', 'trainer']), RouteNames.telegramOffer);
    });

    test('trainer: сразу экран тренера, без Telegram и приглашения', () {
      expect(next(['trainer']), RouteNames.trainerWebOnly);
    });

    test('admin: сразу экран администратора, без приглашения', () {
      expect(next(['admin']), RouteNames.adminWebOnly);
    });
  });
}
