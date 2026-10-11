import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';

/// `refreshListenable` роутера: дёргается **только при смене факта наличия
/// сессии** (неизвестно / нет / есть), а не на каждое событие. Обновление
/// профиля или токена иначе пересобрало бы маршрут и потеряло экран.
class SessionRefreshListenable extends ChangeNotifier {
  SessionRefreshListenable(SessionCubit session)
    : _presence = _presenceOf(session.state) {
    _subscription = session.stream.listen((state) {
      final presence = _presenceOf(state);
      if (presence == _presence) return;

      _presence = presence;
      notifyListeners();
    });
  }

  late final StreamSubscription<SessionState> _subscription;
  int _presence;

  static int _presenceOf(SessionState state) => switch (state) {
    SessionUnknown() => 0,
    SessionUnauthenticated() => 1,
    SessionAuthenticated() => 2,
  };

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
