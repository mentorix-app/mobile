import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/invite_state.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';

class InviteCubit extends Cubit<InviteState> {
  InviteCubit(this._repository, this._session, this._flow)
    : super(const InviteInitial());

  final AuthRepository _repository;
  final SessionCubit _session;
  final OnboardingFlow _flow;

  /// [input] — токен, `inv_<токен>` или вся ссылка: сервер принимает любой
  /// вид, поэтому строка уходит как есть.
  Future<void> accept(String input) async {
    if (state is InviteInProgress) return;
    emit(const InviteInProgress());

    try {
      final acceptance = await _repository.acceptInvite(input);
      await _markDone();
      if (isClosed) return;
      emit(InviteAccepted(acceptance));
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      emit(InviteFailed(failure));
    }
  }

  Future<void> skip() async {
    await _markDone();
    if (isClosed) return;
    emit(const InviteSkipped());
  }

  Future<void> _markDone() async {
    final session = _session.state;
    if (session is SessionAuthenticated) {
      await _flow.completeInvite(session.profile.userId);
    }
  }
}
