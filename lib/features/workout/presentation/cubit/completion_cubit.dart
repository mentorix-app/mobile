import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_target.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/usecases/complete_workout_day.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/completion_state.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_state.dart';

/// Отметка одного дня выполненным. Отменить её нельзя, поэтому порядок строгий:
/// 1. Слепок ([CompletionTarget]) берётся из **загруженной** программы при
///    открытии экрана и уходит на сервер без изменений.
/// 2. Успех (201): программа перезагружается с сервера — выполненность берётся
///    только оттуда, локально день не помечается.
/// 3. `409 program_changed`: программа перезагружается, слепок обновляется, но
///    запрос **не** повторяется сам — пользователь должен увидеть новый день и
///    отправить заново. Введённый текст хранит экран, не кубит.
/// 4. `409 workout_already_completed`, `404 day_not_found`, пропавшее назначение:
///    программа перезагружается, экран закрывается с пояснением.
class CompletionCubit extends Cubit<CompletionState> {
  CompletionCubit({
    required ProgramCubit program,
    required String dayKey,
    required CompleteWorkoutDay completeDay,
  }) : _program = program,
       _dayKey = dayKey,
       _completeDay = completeDay,
       super(const CompletionIdle()) {
    final loaded = program.state;
    final data = loaded is ProgramLoaded ? loaded.data : null;
    final target = data?.completionTargetFor(dayKey);
    final located = data?.locate(dayKey);

    if (data == null || !data.hasProgram) {
      _target = null;
      emit(const CompletionClosed(CompletionCloseReason.notAssigned));
    } else if (located != null && data.isCompleted(located.day)) {
      _target = null;
      emit(const CompletionClosed(CompletionCloseReason.alreadyCompleted));
    } else if (target == null) {
      _target = null;
      emit(const CompletionClosed(CompletionCloseReason.dayGone));
    } else {
      _target = target;
    }
  }

  final ProgramCubit _program;
  final String _dayKey;
  final CompleteWorkoutDay _completeDay;

  CompletionTarget? _target;

  /// Отправляет результат. Повторный вызов, пока идёт отправка или после
  /// завершения, игнорируется. Текст готовит use case: обрезает пробелы, убирает
  /// запрещённые символы, проверяет длину.
  Future<void> submit(String text) async {
    final target = _target;
    if (target == null ||
        state is CompletionSubmitting ||
        state is CompletionDone ||
        state is CompletionClosed) {
      return;
    }

    emit(const CompletionSubmitting());

    try {
      await _completeDay(
        trainerId: _program.trainerId,
        target: target,
        text: text,
      );
    } on WorkoutFailure catch (failure) {
      await _onFailure(failure);
      return;
    }

    final refreshed = await _refreshUntilCompleted();
    if (isClosed) return;
    emit(CompletionDone(refreshFailed: !refreshed));
  }

  /// Обновляет программу после отметки. Если уже шло обновление, начатое **до**
  /// отметки, оно вернёт старые данные, поэтому при необходимости спрашиваем ещё
  /// раз. `true` — программа свежая и день в ней выполнен.
  Future<bool> _refreshUntilCompleted() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final ok = await _program.refresh(silent: true);
      if (!ok) return false;
      if (_isCompleted(_program.state)) return true;
    }
    // Сервер ответил 201, но в `completed_days` дня нет: отметка записана, экран
    // выполненность обновит при следующей загрузке.
    return false;
  }

  bool _isCompleted(ProgramState state) {
    if (state is! ProgramLoaded) return false;
    final located = state.data.locate(_dayKey);
    return located != null && state.data.isCompleted(located.day);
  }

  Future<void> _onFailure(WorkoutFailure failure) async {
    switch (failure) {
      case WorkoutProgramChangedFailure():
        await _onProgramChanged(failure);
      case WorkoutAlreadyCompletedFailure():
        await _closeAfterRefresh(CompletionCloseReason.alreadyCompleted);
      case WorkoutDayNotFoundFailure():
        await _closeAfterRefresh(CompletionCloseReason.dayGone);
      default:
        if (isClosed) return;
        emit(CompletionFailed(failure));
    }
  }

  Future<void> _closeAfterRefresh(CompletionCloseReason reason) async {
    await _program.refresh(silent: true);
    if (isClosed) return;
    emit(CompletionClosed(reason));
  }

  /// Тренер поменял программу: перезагружаем её и берём новый слепок. Что делать
  /// дальше, зависит от новой программы.
  Future<void> _onProgramChanged(WorkoutFailure failure) async {
    final refreshed = await _program.refresh(silent: true);
    if (isClosed) return;

    final state = _program.state;
    final TrainerProgram? data = state is ProgramLoaded ? state.data : null;

    if (!refreshed || data == null) {
      // Свежую программу получить не удалось: слепок прежний, повтор снова даст
      // 409. Сообщаем об этом, пользователь повторит, когда связь вернётся.
      emit(CompletionFailed(failure));
      return;
    }

    if (!data.hasProgram) {
      _target = null;
      emit(const CompletionClosed(CompletionCloseReason.notAssigned));
      return;
    }

    final located = data.locate(_dayKey);
    if (located != null && data.isCompleted(located.day)) {
      _target = null;
      emit(const CompletionClosed(CompletionCloseReason.alreadyCompleted));
      return;
    }

    final target = data.completionTargetFor(_dayKey);
    if (target == null) {
      _target = null;
      emit(const CompletionClosed(CompletionCloseReason.dayGone));
      return;
    }

    // Новый слепок; запрос не повторяем — решает пользователь.
    _target = target;
    emit(const CompletionIdle(programChanged: true));
  }
}
