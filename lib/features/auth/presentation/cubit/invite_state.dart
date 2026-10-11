import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/auth/domain/entities/invite_acceptance.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

sealed class InviteState extends Equatable {
  const InviteState();

  @override
  List<Object?> get props => [];
}

class InviteInitial extends InviteState {
  const InviteInitial();
}

class InviteInProgress extends InviteState {
  const InviteInProgress();
}

class InviteAccepted extends InviteState {
  const InviteAccepted(this.acceptance);

  final InviteAcceptance acceptance;

  @override
  List<Object?> get props => [acceptance];
}

/// Пользователь отложил приглашение.
class InviteSkipped extends InviteState {
  const InviteSkipped();
}

class InviteFailed extends InviteState {
  const InviteFailed(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}
