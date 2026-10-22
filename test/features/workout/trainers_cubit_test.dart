import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/trainers_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/trainers_state.dart';

import '../../helpers/workout_fakes.dart';

void main() {
  late FakeWorkoutRepository repository;
  late TrainersCubit cubit;
  late List<TrainersState> states;
  late StreamSubscription<TrainersState> subscription;

  setUp(() {
    repository = FakeWorkoutRepository()..trainersResult = [aziz];
    cubit = TrainersCubit(repository);
    states = [];
    subscription = cubit.stream.listen(states.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await cubit.close();
  });

  test('начальное состояние — загрузка, запрос сам не уходит', () {
    expect(cubit.state, const TrainersLoading());
    expect(repository.trainersCalls, 0);
  });

  test('load: загрузка → список', () async {
    cubit = TrainersCubit(repository);
    final emitted = <TrainersState>[];
    final sub = cubit.stream.listen(emitted.add);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(emitted, [const TrainersLoading(), const TrainersLoaded([aziz])]);
    await sub.cancel();
    await cubit.close();
  });

  test('load: пустой список — Loaded без тренеров', () async {
    repository.trainersResult = const [];

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states.last, const TrainersLoaded([]));
  });

  test('load: ошибка → Failed с тем же объектом ошибки', () async {
    const failure = WorkoutNetworkFailure();
    repository.trainersFailure = failure;

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states.last, isA<TrainersFailed>());
    expect((states.last as TrainersFailed).failure, same(failure));
  });

  test('«Повторить» после ошибки: снова скелетон, затем список', () async {
    repository.trainersFailure = const WorkoutNetworkFailure();
    await cubit.load();

    repository.trainersFailure = null;
    await Future<void>.delayed(Duration.zero);
    states.clear();
    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states, [const TrainersLoading(), const TrainersLoaded([aziz])]);
  });

  test('refresh: новый список заменяет старый без скелетона', () async {
    await cubit.load();
    const other = aziz;
    repository.trainersResult = [aziz, other];
    await Future<void>.delayed(Duration.zero);
    states.clear();

    await cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(states.whereType<TrainersLoading>(), isEmpty);
    expect((states.last as TrainersLoaded).trainers, hasLength(2));
  });

  test('refresh с ошибкой: список остаётся, ошибка в refreshFailure', () async {
    await cubit.load();
    const failure = WorkoutServerUnavailableFailure();
    repository.trainersFailure = failure;
    await Future<void>.delayed(Duration.zero);
    states.clear();

    await cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    final last = states.last as TrainersLoaded;
    expect(last.trainers, [aziz]);
    expect(last.refreshFailure, same(failure));
    expect(states.whereType<TrainersFailed>(), isEmpty);
  });

  test('одинаковая ошибка refresh два раза подряд будит экран оба раза', () async {
    await cubit.load();
    repository.trainersFailure = const WorkoutNetworkFailure();
    await Future<void>.delayed(Duration.zero);
    states.clear();

    await cubit.refresh();
    await cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    final withFailure = states.whereType<TrainersLoaded>().where(
      (s) => s.refreshFailure != null,
    );
    expect(withFailure, hasLength(2));
  });

  test('успешный refresh после ошибки снимает refreshFailure', () async {
    await cubit.load();
    repository.trainersFailure = const WorkoutNetworkFailure();
    await cubit.refresh();

    repository.trainersFailure = null;
    await cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    expect((states.last as TrainersLoaded).refreshFailure, isNull);
  });

  test('refresh до загрузки (ошибка или скелетон) работает как load', () async {
    repository.trainersFailure = const WorkoutNetworkFailure();
    await cubit.load();
    repository.trainersFailure = null;

    await cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(states.last, const TrainersLoaded([aziz]));
    expect(repository.trainersCalls, 2);
  });

  test('кубит закрыт до ответа — emit не вызывается', () async {
    final gate = Completer<void>();
    repository.trainersGate = gate;

    final loading = cubit.load();
    await cubit.close();
    gate.complete();

    await expectLater(loading, completes);
    expect(states.whereType<TrainersLoaded>(), isEmpty);
  });
}
