import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

/// Старт: токены ещё читаются, `/auth/me` ещё не вернулся.
/// [failure] — запрос не удался из-за связи: токены целы, можно повторить.
class SessionUnknown extends SessionState {
  const SessionUnknown({this.failure});

  final AuthFailure? failure;

  @override
  List<Object?> get props => [failure];
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}
