import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_state.dart';

import '../../helpers/workout_builders.dart';
import '../../helpers/workout_fakes.dart';

void main() {
  late FakeWorkoutRepository repository;
  late ProgramCubit cubit;
  late List<ProgramState> states;
  late StreamSubscription<ProgramState> subscription;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    repository = FakeWorkoutRepository()..programResult = stageProgram();
    cubit = ProgramCubit('aziz', repository);
    states = [];
    subscription = cubit.stream.listen(states.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await cubit.close();
  });

  test('запрашивает программу именно этого тренера', () async {
    await cubit.load();

    expect(repository.programTrainerIds, ['aziz']);
  });

  test('load: загрузка → программа', () async {
    await cubit.load();
    await settle();

    expect(states, [const ProgramLoading(), ProgramLoaded(stageProgram())]);
  });

  test('load: программа не назначена — Loaded без программы, не ошибка', () async {
    repository.programResult = const TrainerProgram(trainerId: 'aziz');
    await cubit.load();
    await settle();

    final loaded = states.last as ProgramLoaded;
    expect(loaded.data.hasProgram, isFalse);
    expect(states.whereType<ProgramFailed>(), isEmpty);
  });

  test('load: ошибка → Failed с тем же объектом', () async {
    const failure = WorkoutNotLinkedFailure();
    repository.programFailure = failure;

    await cubit.load();
    await settle();

    expect((states.last as ProgramFailed).failure, same(failure));
    expect(failure.canRetry, isFalse);
  });

  test('refresh: данные остаются, новые заменяют старые, скелетона нет', () async {
    await cubit.load();
    repository.programResult = stageProgram(completed: {'day-1'});
    await settle();
    states.clear();

    await cubit.refresh();
    await settle();

    expect(states.whereType<ProgramLoading>(), isEmpty);
    expect((states.last as ProgramLoaded).data.completedTrainingDays, 1);
  });

  test('выполненность меняется только после ответа сервера', () async {
    await cubit.load();
    await settle();

    expect((cubit.state as ProgramLoaded).data.completedTrainingDays, 0);

    repository.programResult = stageProgram(completed: {'day-2'});
    await cubit.refresh();

    expect((cubit.state as ProgramLoaded).data.completedTrainingDays, 1);
  });

  test('refresh с ошибкой: данные остаются, ошибка в refreshFailure', () async {
    await cubit.load();
    const failure = WorkoutServerUnavailableFailure();
    repository.programFailure = failure;
    await settle();
    states.clear();

    await cubit.refresh();
    await settle();

    final last = states.last as ProgramLoaded;
    expect(last.data, stageProgram());
    expect(last.refreshFailure, same(failure));
  });

  test('одинаковая ошибка refresh подряд будит экран оба раза', () async {
    await cubit.load();
    repository.programFailure = const WorkoutNetworkFailure();
    await settle();
    states.clear();

    await cubit.refresh();
    await cubit.refresh();
    await settle();

    expect(
      states.whereType<ProgramLoaded>().where((s) => s.refreshFailure != null),
      hasLength(2),
    );
  });

  test('тихое обновление: ошибка не сообщается, данные целы', () async {
    await cubit.load();
    repository.programFailure = const WorkoutNetworkFailure();
    await settle();
    states.clear();

    await cubit.refresh(silent: true);
    await settle();

    expect(states.whereType<ProgramLoaded>().where((s) => s.refreshFailure != null), isEmpty);
    expect(cubit.state, ProgramLoaded(stageProgram()));
  });

  test('тихое обновление до загрузки (скелетон) запроса не шлёт', () async {
    final gate = Completer<void>();
    repository.programGate = gate;
    final loading = cubit.load();
    await settle();

    await cubit.refresh(silent: true);

    expect(repository.programCalls, 1);
    gate.complete();
    await loading;
  });

  test('refresh во время refresh ждёт текущий запрос, второй не уходит', () async {
    await cubit.load();
    final gate = Completer<void>();
    repository.programGate = gate;

    final first = cubit.refresh();
    final second = cubit.refresh(silent: true);
    final third = cubit.refresh();
    await settle();

    expect(repository.programCalls, 2, reason: 'load + один refresh');

    gate.complete();
    await Future.wait([first, second, third]);

    repository.programGate = null;
    await cubit.refresh();
    expect(repository.programCalls, 3, reason: 'после завершения новый refresh уходит');
  });

  test('Future refresh завершается только после ответа', () async {
    await cubit.load();
    final gate = Completer<void>();
    repository.programGate = gate;
    var done = false;

    final refreshing = cubit.refresh().then((_) => done = true);
    await settle();
    expect(done, isFalse);

    gate.complete();
    await refreshing;
    expect(done, isTrue);
  });

  test('Future refresh завершается и на ошибке', () async {
    await cubit.load();
    repository.programFailure = const WorkoutNetworkFailure();

    await expectLater(cubit.refresh(), completes);
  });

  test('refresh из ошибки работает как load', () async {
    repository.programFailure = const WorkoutNetworkFailure();
    await cubit.load();
    repository.programFailure = null;

    await cubit.refresh();
    await settle();

    expect(states.last, ProgramLoaded(stageProgram()));
  });

  test('кубит закрыт до ответа — emit не вызывается', () async {
    final gate = Completer<void>();
    repository.programGate = gate;

    final loading = cubit.load();
    await cubit.close();
    gate.complete();

    await expectLater(loading, completes);
    expect(states.whereType<ProgramLoaded>(), isEmpty);
  });

  group('refresh возвращает, пришли ли свежие данные', () {
    test('успех — true', () async {
      await cubit.load();

      expect(await cubit.refresh(), isTrue);
      expect(await cubit.refresh(silent: true), isTrue);
    });

    test('ошибка — false, показанные данные остались', () async {
      await cubit.load();
      repository.programFailure = const WorkoutNetworkFailure();

      expect(await cubit.refresh(), isFalse);
      expect(await cubit.refresh(silent: true), isFalse);
      expect(cubit.state, isA<ProgramLoaded>());
    });

    test('тихое обновление, пока идёт первая загрузка, — false без запроса', () async {
      final gate = Completer<void>();
      repository.programGate = gate;
      final loading = cubit.load();
      await settle();

      expect(await cubit.refresh(silent: true), isFalse);
      expect(repository.programCalls, 1);

      gate.complete();
      await loading;
    });

    test('обновление из ошибки работает как load: true, если загрузилось', () async {
      repository.programFailure = const WorkoutNetworkFailure();
      await cubit.load();
      repository.programFailure = null;

      expect(await cubit.refresh(), isTrue);
    });

    test('параллельные вызовы получают результат одного запроса', () async {
      await cubit.load();
      final gate = Completer<void>();
      repository.programGate = gate;

      final results = Future.wait([cubit.refresh(), cubit.refresh(silent: true)]);
      await settle();
      gate.complete();

      expect(await results, [true, true]);
      expect(repository.programCalls, 2);
    });
  });
}
