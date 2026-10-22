import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/repositories/workout_repository.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/trainers_state.dart';

/// Список тренеров клиента (`GET /client/trainers`). Список запрашивается
/// заново, а не берётся из сессии: тот снят при входе и мог устареть.
class TrainersCubit extends Cubit<TrainersState> {
  TrainersCubit(this._repository) : super(const TrainersLoading());

  final WorkoutRepository _repository;

  /// Первая загрузка и «Повторить» после ошибки: показывает скелетон.
  Future<void> load() async {
    emit(const TrainersLoading());
    await _fetch();
  }

  /// Pull-to-refresh. Показанный список не стирается: при ошибке он остаётся,
  /// а [TrainersLoaded.refreshFailure] будит экран, чтобы сообщить об ошибке.
  Future<void> refresh() async {
    final current = state;
    if (current is! TrainersLoaded) return load();

    // Сначала снимаем прошлую ошибку: одинаковая ошибка подряд — это тот же
    // объект, и без этого `emit` отбросил бы её как «не изменилось».
    emit(TrainersLoaded(current.trainers));
    await _fetch(previous: current);
  }

  Future<void> _fetch({TrainersLoaded? previous}) async {
    try {
      final trainers = await _repository.trainers();
      if (isClosed) return;
      emit(TrainersLoaded(trainers));
    } on WorkoutFailure catch (failure) {
      if (isClosed) return;
      emit(
        previous == null
            ? TrainersFailed(failure)
            : TrainersLoaded(previous.trainers, refreshFailure: failure),
      );
    }
  }
}
