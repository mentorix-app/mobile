import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';

/// Глобальная сессия приложения: один экземпляр на всё приложение.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository, SessionExpiredNotifier sessionExpired)
    : super(const SessionUnknown()) {
    _expiredSubscription = sessionExpired.stream.listen((_) => _onExpired());
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _expiredSubscription;

  /// Старт приложения: читает токены и запрашивает `/auth/me`.
  Future<void> start() async {
    emit(const SessionUnknown());

    try {
      final hasSession = await _repository.restoreSession();
      if (isClosed) return;

      if (!hasSession) {
        emit(const SessionUnauthenticated());
        return;
      }

      final profile = await _repository.getProfile(forceRefresh: true);
      if (isClosed) return;
      emit(SessionAuthenticated(profile));
    } on SessionExpiredFailure {
      await _repository.clearLocalSession();
      if (isClosed) return;
      emit(const SessionUnauthenticated());
    } on AuthFailure catch (failure) {
      // Нет связи или сервер спит: токены целы, предлагаем повторить.
      if (isClosed) return;
      emit(SessionUnknown(failure: failure));
    }
  }

  /// Вызывается после входа и после привязки Telegram — с свежим профилем.
  void setAuthenticated(UserProfile profile) {
    emit(SessionAuthenticated(profile));
  }

  Future<void> logout() async {
    await _repository.logout();
    if (isClosed) return;
    emit(const SessionUnauthenticated());
  }

  Future<void> logoutAll() async {
    await _repository.logoutAll();
    if (isClosed) return;
    emit(const SessionUnauthenticated());
  }

  /// Refresh вернул 401: перехватчик уже очистил токены.
  Future<void> _onExpired() async {
    await _repository.clearLocalSession();
    if (isClosed) return;
    emit(const SessionUnauthenticated());
  }

  @override
  Future<void> close() async {
    await _expiredSubscription.cancel();
    return super.close();
  }
}
