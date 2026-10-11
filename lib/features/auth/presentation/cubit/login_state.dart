import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginInProgress extends LoginState {
  const LoginInProgress();
}

class LoginFailed extends LoginState {
  const LoginFailed(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}
