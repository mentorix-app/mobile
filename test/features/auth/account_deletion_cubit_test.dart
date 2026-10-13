import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/account_deletion_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/account_deletion_state.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late SessionCubit session;
  late SharedPreferences prefs;
  late AccountDeletionCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.onboardingTelegramOfferDone('user-1'): true,
      StorageKeys.onboardingInviteDone('user-1'): true,
    });
    prefs = await SharedPreferences.getInstance();

    repository = FakeAuthRepository()..hasSession = true;
    session = SessionCubit(repository, SessionExpiredNotifier());
    await session.authenticate();
    cubit = AccountDeletionCubit(repository, session, OnboardingFlow(prefs));
  });

  tearDown(() async {
    await cubit.close();
    await session.close();
  });

  test('успех: сессия закончена, отметки онбординга удалены', () async {
    await cubit.delete();

    expect(cubit.state, const AccountDeletionDone());
    expect(session.state, const SessionUnauthenticated());
    expect(repository.deleteCalls, [false]);
    expect(
      prefs.containsKey(StorageKeys.onboardingInviteDone('user-1')),
      isFalse,
    );
    expect(
      prefs.containsKey(StorageKeys.onboardingTelegramOfferDone('user-1')),
      isFalse,
    );
  });

  test('ошибка: сессия цела, причина в состоянии', () async {
    repository.deleteFailure = const AccountDeletionUnavailableFailure();

    await cubit.delete();

    expect(
      cubit.state,
      const AccountDeletionFailed(AccountDeletionUnavailableFailure()),
    );
    expect(session.state, isA<SessionAuthenticated>());
    expect(
      prefs.containsKey(StorageKeys.onboardingInviteDone('user-1')),
      isTrue,
      reason: 'аккаунт не удалён — отметки остаются',
    );
  });

  test('окно Apple закрыто: тихо возвращаемся, ошибки нет', () async {
    repository.deleteFailure = const SocialSignInCancelledFailure();

    await cubit.delete();

    expect(cubit.state, const AccountDeletionIdle());
    expect(session.state, isA<SessionAuthenticated>());
  });

  group('повтор окна Apple', () {
    for (final failure in const <AuthFailure>[
      AppleProofRejectedFailure(),
      AppleAccountMismatchFailure(),
      AppleAuthorizationRequiredFailure(),
    ]) {
      test('после ${failure.runtimeType} повтор сразу с окном Apple', () async {
        repository.deleteFailure = failure;
        await cubit.delete();

        expect(
          (cubit.state as AccountDeletionFailed).canRetryWithApple,
          isTrue,
        );

        repository.deleteFailure = null;
        await cubit.delete();

        expect(repository.deleteCalls, [false, true]);
        expect(cubit.state, const AccountDeletionDone());
      });
    }

    test('после 502/503 повтор снова начинается без окна Apple', () async {
      repository.deleteFailure = const AccountDeletionFailedFailure();
      await cubit.delete();

      expect(
        (cubit.state as AccountDeletionFailed).canRetryWithApple,
        isFalse,
        reason: 'у аккаунта без Apple окно не нужно вовсе',
      );

      repository.deleteFailure = null;
      await cubit.delete();

      expect(repository.deleteCalls, [false, false]);
    });
  });

  test('второй вызов во время удаления игнорируется', () async {
    final gate = repository.gate = Completer<void>();

    final first = cubit.delete();
    await cubit.delete();
    gate.complete();
    await first;

    expect(repository.deleteCalls, hasLength(1));
  });
}
