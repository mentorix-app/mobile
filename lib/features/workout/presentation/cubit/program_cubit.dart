import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/repositories/workout_repository.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_state.dart';

/// Программа клиента у одного тренера. Выполненность дней берётся только из
/// `completed_days` ответа сервера: локальных отметок нет, день мог быть
/// отмечен в Telegram-боте.
class ProgramCubit extends Cubit<ProgramState> {
  ProgramCubit(this.trainerId, this._repository) : super(const ProgramLoading());

  final String trainerId;
  final WorkoutRepository _repository;

  /// Обновление уже идёт: повторный вызов (pull-to-refresh и возврат в
  /// приложение подряд) ждёт его, а не шлёт второй запрос.
  Future<bool>? _inFlight;

  /// Первая загрузка и «Повторить» после ошибки: показывает скелетон.
  Future<void> load() async {
    emit(const ProgramLoading());
    await _fetch();
  }

  /// Обновление без скелетона: показанные данные остаются, пока не придут новые.
  ///
  /// [silent] — тихое обновление (возврат в приложение, после отметки дня): при
  /// ошибке ничего не сообщается, остаются прежние данные. Pull-to-refresh
  /// сообщает об ошибке уведомлением ([ProgramLoaded.refreshFailure]).
  ///
  /// Future завершается, когда обновление закончилось (успехом или ошибкой), —
  /// индикатор pull-to-refresh не прячется раньше. Результат — `true`, если пришли
  /// свежие данные; `false` — обновление не удалось (или его нет смысла
  /// запускать), показаны прежние.
  Future<bool> refresh({bool silent = false}) {
    final running = _inFlight;
    if (running != null) return running;

    final current = state;
    if (current is! ProgramLoaded) {
      // Скелетон или ошибка: обновлять нечего, загружаем заново.
      if (silent && current is ProgramLoading) return Future.value(false);
      return load().then((_) => state is ProgramLoaded);
    }

    // Сначала снимаем прошлую ошибку: одинаковая ошибка подряд — тот же объект,
    // и без этого `emit` отбросил бы её как «не изменилось».
    emit(ProgramLoaded(current.data));
    return _inFlight = _fetch(previous: current, silent: silent).whenComplete(
      () => _inFlight = null,
    );
  }

  Future<bool> _fetch({ProgramLoaded? previous, bool silent = false}) async {
    try {
      final data = await _repository.program(trainerId);
      if (isClosed) return false;
      emit(ProgramLoaded(data));
      return true;
    } on WorkoutFailure catch (failure) {
      if (isClosed) return false;
      if (previous == null) {
        emit(ProgramFailed(failure));
      } else if (!silent) {
        emit(ProgramLoaded(previous.data, refreshFailure: failure));
      }
      return false;
    }
  }
}
