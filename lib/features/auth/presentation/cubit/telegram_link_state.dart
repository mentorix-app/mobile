import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

sealed class TelegramLinkState extends Equatable {
  const TelegramLinkState();

  @override
  List<Object?> get props => [];
}

class TelegramLinkInitial extends TelegramLinkState {
  const TelegramLinkInitial();
}

class TelegramLinkInProgress extends TelegramLinkState {
  const TelegramLinkInProgress();
}

/// Telegram привязан, токены заменены, профиль обновлён.
class TelegramLinkSuccess extends TelegramLinkState {
  const TelegramLinkSuccess();
}

/// Пользователь отказался от привязки.
class TelegramLinkSkipped extends TelegramLinkState {
  const TelegramLinkSkipped();
}

class TelegramLinkFailed extends TelegramLinkState {
  const TelegramLinkFailed(this.failure, {this.codeSpent = false});

  final AuthFailure failure;

  /// Сервер ответил на отправку кода (кроме 429 и 401): код одноразовый и
  /// потрачен, повторять его бессмысленно — нужен новый из бота.
  final bool codeSpent;

  @override
  List<Object?> get props => [failure, codeSpent];
}
