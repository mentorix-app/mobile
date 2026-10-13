import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_state.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';

/// Вход. После успеха профиль уходит в [SessionCubit], а роутер сам
/// переводит пользователя на следующий шаг.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository, this._session) : super(const LoginInitial());

  final AuthRepository _repository;
  final SessionCubit _session;

  bool get isGoogleAvailable => _repository.isGoogleSignInAvailable;
  bool get isAppleAvailable => _repository.isAppleSignInAvailable;

  Future<void> signInWithGoogle() => _signIn(_repository.signInWithGoogle);

  Future<void> signInWithApple() => _signIn(_repository.signInWithApple);

  Future<void> _signIn(Future<void> Function() signIn) async {
    if (state is LoginInProgress) return;
    emit(const LoginInProgress());

    try {
      await signIn();
      // Порядок из контракта: /auth/me, /client/trainers, потом экраны.
      await _session.authenticate();
      if (isClosed) return;

      emit(const LoginInitial());
    } on SocialSignInCancelledFailure {
      if (isClosed) return;
      emit(const LoginInitial());
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      emit(LoginFailed(failure));
    }
  }
}
