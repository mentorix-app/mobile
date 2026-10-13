import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
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

  /// Старт приложения: читает токены, затем `/auth/me` и `/client/trainers`.
  Future<void> start() async {
    emit(const SessionUnknown());

    try {
      final hasSession = await _repository.restoreSession();
      if (isClosed) return;

      if (!hasSession) {
        emit(const SessionUnauthenticated());
        return;
      }

      await authenticate();
    } on AuthFailure catch (failure) {
      // 401 на refresh и 404 на /auth/me (учётную запись перенесли) — конец
      // сессии: токены очищаются, пользователь попадает на экран входа.
      if (failure is SessionExpiredFailure ||
          failure is AccountNotFoundFailure) {
        await _repository.clearLocalSession();
        if (isClosed) return;
        emit(const SessionUnauthenticated());
        return;
      }

      // Нет связи или сервер спит: токены целы, предлагаем повторить.
      if (isClosed) return;
      emit(SessionUnknown(failure: failure));
    }
  }

  /// Вызывается после входа и после привязки Telegram. Порядок из контракта:
  /// сначала `GET /auth/me`, затем `GET /client/trainers` — по его ответу
  /// решается, показывать ли экран приглашения. Бросает [AuthFailure]; сессию
  /// не завершает — решение за вызывающим.
  Future<void> authenticate() async {
    final profile = await _repository.getProfile(forceRefresh: true);
    final trainers = await _repository.getTrainers();
    if (isClosed) return;
    emit(SessionAuthenticated(profile, trainers: trainers));
  }

  Future<void> logout() async {
    await _repository.logout();
    if (isClosed) return;
    emit(const SessionUnauthenticated());
  }

  /// Аккаунт удалён на сервере: токены репозиторий уже очистил, остаётся
  /// закончить сессию — роутер уведёт на вход.
  void onAccountDeleted() => emit(const SessionUnauthenticated());

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
