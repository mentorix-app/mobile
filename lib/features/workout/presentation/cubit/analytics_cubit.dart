import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/repositories/stats_repository.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/analytics_state.dart';

/// Статистика клиента у одного тренера: прогресс, активность, результаты и ответы
/// тренера (`GET /client/trainers/{id}/analytics`). Только чтение.
class AnalyticsCubit extends Cubit<AnalyticsState> {
  AnalyticsCubit(this.trainerId, this._repository)
    : super(const AnalyticsLoading());

  final String trainerId;
  final StatsRepository _repository;

  /// Первая загрузка и «Повторить»: показывает скелетон.
  Future<void> load() async {
    emit(const AnalyticsLoading());
    await _fetch();
  }

  /// Pull-to-refresh: показанные данные остаются; при ошибке они же и
  /// [AnalyticsLoaded.refreshFailure]. Future завершается, когда обновление
  /// закончилось (успехом или ошибкой).
  Future<void> refresh() async {
    final current = state;
    if (current is! AnalyticsLoaded) return load();

    // Прошлую ошибку снимаем заранее: одинаковая ошибка подряд — тот же объект, и
    // без этого `emit` отбросил бы её как «не изменилось».
    emit(AnalyticsLoaded(current.data));
    await _fetch(previous: current);
  }

  Future<void> _fetch({AnalyticsLoaded? previous}) async {
    try {
      final data = await _repository.analytics(trainerId);
      if (isClosed) return;
      emit(AnalyticsLoaded(data));
    } on WorkoutFailure catch (failure) {
      if (isClosed) return;
      emit(
        previous == null
            ? AnalyticsFailed(failure)
            : AnalyticsLoaded(previous.data, refreshFailure: failure),
      );
    }
  }
}
