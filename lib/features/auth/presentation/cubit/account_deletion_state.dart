import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

sealed class AccountDeletionState extends Equatable {
  const AccountDeletionState();

  @override
  List<Object?> get props => [];
}

class AccountDeletionIdle extends AccountDeletionState {
  const AccountDeletionIdle();
}

class AccountDeletionInProgress extends AccountDeletionState {
  const AccountDeletionInProgress();
}

/// Аккаунт удалён, сессия закончена: роутер уводит на экран входа.
class AccountDeletionDone extends AccountDeletionState {
  const AccountDeletionDone();
}

class AccountDeletionFailed extends AccountDeletionState {
  const AccountDeletionFailed(this.failure);

  final AuthFailure failure;

  /// Отказ Apple: окно можно показать заново.
  bool get canRetryWithApple => switch (failure) {
    AppleAuthorizationRequiredFailure() ||
    AppleProofRejectedFailure() ||
    AppleAccountMismatchFailure() => true,
    _ => false,
  };

  @override
  List<Object?> get props => [failure];
}
