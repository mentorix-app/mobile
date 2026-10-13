import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/account_deletion_state.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';

/// Удаление аккаунта (`DELETE /auth/me`). После успеха токены уже очищены
/// репозиторием, [SessionCubit] становится «без сессии», а роутер уводит на вход.
class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit(this._repository, this._session, this._flow)
    : super(const AccountDeletionIdle());

  final AuthRepository _repository;
  final SessionCubit _session;
  final OnboardingFlow _flow;

  /// Apple уже потребовала подтверждения (422 или отказ): повтор сразу
  /// показывает окно Apple, а не начинает с запроса без тела. После ошибки
  /// сервера (502/503) флаг не ставится: у аккаунта без входа через Apple окно
  /// Apple не нужно вовсе.
  bool _confirmWithApple = false;

  Future<void> delete() async {
    if (state is AccountDeletionInProgress) return;
    emit(const AccountDeletionInProgress());

    final session = _session.state;
    final userId = session is SessionAuthenticated
        ? session.profile.userId
        : null;

    try {
      await _repository.deleteAccount(confirmWithApple: _confirmWithApple);
      if (userId != null) await _flow.forget(userId);

      _session.onAccountDeleted();
      if (isClosed) return;
      emit(const AccountDeletionDone());
    } on SocialSignInCancelledFailure {
      // Закрыл окно Apple: аккаунт не тронут, ошибкой это не считается.
      if (isClosed) return;
      emit(const AccountDeletionIdle());
    } on AuthFailure catch (failure) {
      if (failure is AppleAuthorizationRequiredFailure ||
          failure is AppleProofRejectedFailure ||
          failure is AppleAccountMismatchFailure) {
        _confirmWithApple = true;
      }
      if (isClosed) return;
      emit(AccountDeletionFailed(failure));
    }
  }
}
