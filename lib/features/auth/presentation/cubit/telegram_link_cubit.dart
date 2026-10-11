import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_state.dart';

/// Предложение привязать Telegram и ввод кода. Один экземпляр на оба экрана.
class TelegramLinkCubit extends Cubit<TelegramLinkState> {
  TelegramLinkCubit(this._repository, this._session, this._flow)
    : super(const TelegramLinkInitial());

  final AuthRepository _repository;
  final SessionCubit _session;
  final OnboardingFlow _flow;

  /// Код уже принят сервером, но `/auth/me` не получен: повтор не должен
  /// отправлять использованный код ещё раз.
  bool _linked = false;

  Future<void> submit(String code) async {
    if (state is TelegramLinkInProgress) return;
    emit(const TelegramLinkInProgress());

    try {
      if (!_linked) {
        await _repository.linkTelegram(code);
        _linked = true;
      }

      // user_id мог поменяться: профиль всегда запрашивается заново.
      final profile = await _repository.getProfile(forceRefresh: true);
      if (isClosed) return;

      _session.setAuthenticated(profile);
      emit(const TelegramLinkSuccess());
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      emit(TelegramLinkFailed(failure));
    }
  }

  Future<void> skip() async {
    final session = _session.state;
    if (session is SessionAuthenticated) {
      await _flow.skipTelegramOffer(session.profile.userId);
    }
    if (isClosed) return;
    emit(const TelegramLinkSkipped());
  }
}
