import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late SessionExpiredNotifier notifier;
  late SessionCubit cubit;

  setUp(() {
    repository = FakeAuthRepository();
    notifier = SessionExpiredNotifier();
    cubit = SessionCubit(repository, notifier);
  });

  tearDown(() async {
    await cubit.close();
    await notifier.dispose();
  });

  test('начальное состояние — unknown', () {
    expect(cubit.state, const SessionUnknown());
  });

  test('нет токенов → unauthenticated, /auth/me не запрашивается', () async {
    repository.hasSession = false;
    repository.profileFailure = const UnknownFailure(); // не должен вызваться

    await cubit.start();

    expect(cubit.state, const SessionUnauthenticated());
  });

  test('токены есть → /auth/me → authenticated(профиль)', () async {
    repository.hasSession = true;

    await cubit.start();

    expect(cubit.state, const SessionAuthenticated(testProfile));
  });

  test('refresh не прошёл (401) → токены очищены, unauthenticated', () async {
    repository.hasSession = true;
    repository.profileFailure = const SessionExpiredFailure();

    await cubit.start();

    expect(cubit.state, const SessionUnauthenticated());
    expect(repository.clearCalls, 1);
  });

  test('нет связи на старте → unknown с ошибкой, токены не трогаем', () async {
    repository.hasSession = true;
    repository.profileFailure = const NetworkFailure();

    await cubit.start();

    expect(cubit.state, const SessionUnknown(failure: NetworkFailure()));
    expect(repository.clearCalls, 0);

    // «Повторить» после появления связи.
    repository.profileFailure = null;
    await cubit.start();
    expect(cubit.state, const SessionAuthenticated(testProfile));
  });

  test('перехватчик сообщил о конце сессии → unauthenticated', () async {
    cubit.setAuthenticated(testProfile);

    notifier.notify();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const SessionUnauthenticated());
    expect(repository.clearCalls, 1);
  });

  test('выход → unauthenticated', () async {
    repository.hasSession = true;
    await cubit.start();

    await cubit.logout();

    expect(cubit.state, const SessionUnauthenticated());
    expect(repository.logoutCalls, 1);
  });
}
