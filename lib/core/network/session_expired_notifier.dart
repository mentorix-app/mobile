import 'dart:async';

/// Сообщает о том, что сессия закончилась: refresh вернул 401 и токены очищены.
/// Слушает `SessionCubit`.
class SessionExpiredNotifier {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
