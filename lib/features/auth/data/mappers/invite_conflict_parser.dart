import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

/// Разбор 409 у `POST /client/invites/accept`.
///
/// Бэкенд пока различает два случая только по тексту `message`. Весь разбор
/// живёт здесь: когда появится поле `code`, меняется один файл.
abstract final class InviteConflictParser {
  static const _consumedMarker = 'invite already consumed';
  static const _clientLimitMarker = 'client limit reached';

  static AuthFailure parse(String? message) {
    final text = message?.toLowerCase() ?? '';

    if (text.contains(_consumedMarker)) {
      return const InviteAlreadyConsumedFailure();
    }
    if (text.contains(_clientLimitMarker)) {
      return const InviteClientLimitReachedFailure();
    }
    return const InviteConflictFailure();
  }
}
