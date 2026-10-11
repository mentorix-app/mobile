/// Лежит в `DioException.error`, когда refresh не удался с 401 (или обновлять
/// нечем): сессия закончена, токены очищены.
class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'SessionExpiredException';
}
