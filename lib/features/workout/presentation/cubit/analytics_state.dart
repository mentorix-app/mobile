import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

sealed class AnalyticsState extends Equatable {
  const AnalyticsState();

  @override
  List<Object?> get props => [];
}

/// Первая загрузка: на экране скелетон.
class AnalyticsLoading extends AnalyticsState {
  const AnalyticsLoading();
}

/// Статистика получена. [refreshFailure] — обновление не удалось, показанные данные
/// остаются, об ошибке сообщает уведомление.
class AnalyticsLoaded extends AnalyticsState {
  const AnalyticsLoaded(this.data, {this.refreshFailure});

  final ClientAnalytics data;
  final WorkoutFailure? refreshFailure;

  @override
  List<Object?> get props => [data, refreshFailure];
}

/// Первая загрузка не удалась: ошибка и (если повтор имеет смысл) «Повторить».
class AnalyticsFailed extends AnalyticsState {
  const AnalyticsFailed(this.failure);

  final WorkoutFailure failure;

  @override
  List<Object?> get props => [failure];
}
