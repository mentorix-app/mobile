import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

/// Почему экран отметки закрывается без отметки: дальше отмечать нечего.
enum CompletionCloseReason {
  /// День уже отмечен (в приложении, в Telegram-боте или прошлой отправкой, ответ
  /// на которую потерялся).
  alreadyCompleted,

  /// Такого дня в программе больше нет или его нельзя отметить.
  dayGone,

  /// Назначения больше нет: тренер снял программу.
  notAssigned,
}

sealed class CompletionState extends Equatable {
  const CompletionState();

  @override
  List<Object?> get props => [];
}

/// Можно вводить результат и отправлять. [programChanged] — тренер обновил
/// программу, пока клиент писал: программа перезагружена, слепок обновлён, но
/// отправлять заново должен сам пользователь, увидев новый день.
class CompletionIdle extends CompletionState {
  const CompletionIdle({this.programChanged = false});

  final bool programChanged;

  @override
  List<Object?> get props => [programChanged];
}

/// Запрос ушёл: кнопка с индикатором, поле и «назад» заблокированы.
class CompletionSubmitting extends CompletionState {
  const CompletionSubmitting();
}

/// Отправка не удалась; введённый текст остаётся, можно повторить.
class CompletionFailed extends CompletionState {
  const CompletionFailed(this.failure);

  final WorkoutFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// Отметка записана (201). [refreshFailed] — отметка сохранена, но свежую
/// программу получить не удалось: выполненность на экранах обновится при
/// следующем обновлении.
class CompletionDone extends CompletionState {
  const CompletionDone({this.refreshFailed = false});

  final bool refreshFailed;

  @override
  List<Object?> get props => [refreshFailed];
}

/// Экран закрывается без отметки.
class CompletionClosed extends CompletionState {
  const CompletionClosed(this.reason);

  final CompletionCloseReason reason;

  @override
  List<Object?> get props => [reason];
}
