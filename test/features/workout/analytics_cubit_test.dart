import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/data/models/client_analytics_model.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/analytics_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/analytics_state.dart';

import '../../helpers/stats_fakes.dart';
import '../../helpers/workout_builders.dart';

void main() {
  late FakeStatsRepository repository;
  late AnalyticsCubit cubit;
  late List<AnalyticsState> states;
  late StreamSubscription<AnalyticsState> subscription;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    repository = FakeStatsRepository()
      ..result = ClientAnalyticsModel.fromJson(loadAnalyticsSample());
    cubit = AnalyticsCubit('aziz', repository);
    states = [];
    subscription = cubit.stream.listen(states.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await cubit.close();
  });

  test('запрашивает статистику именно этого тренера', () async {
    await cubit.load();

    expect(repository.trainerIds, ['aziz']);
  });

  test('load: загрузка → данные', () async {
    await cubit.load();
    await settle();

    expect(states.first, const AnalyticsLoading());
    expect((states.last as AnalyticsLoaded).data.recentCompletions, hasLength(2));
  });

  test('load: ошибка → Failed с тем же объектом', () async {
    const failure = WorkoutNotLinkedFailure();
    repository.failure = failure;

    await cubit.load();
    await settle();

    expect((states.last as AnalyticsFailed).failure, same(failure));
    expect(failure.canRetry, isFalse);
  });

  test('«Повторить» после ошибки: скелетон, затем данные', () async {
    repository.failure = const WorkoutNetworkFailure();
    await cubit.load();
    repository.failure = null;
    await settle();
    states.clear();

    await cubit.load();
    await settle();

    expect(states.first, const AnalyticsLoading());
    expect(states.last, isA<AnalyticsLoaded>());
  });

  test('refresh: новые данные без скелетона', () async {
    await cubit.load();
    repository.result = const ClientAnalyticsModel();
    await settle();
    states.clear();

    await cubit.refresh();
    await settle();

    expect(states.whereType<AnalyticsLoading>(), isEmpty);
    expect((states.last as AnalyticsLoaded).data.recentCompletions, isEmpty);
  });

  test('refresh с ошибкой: данные остаются, ошибка в refreshFailure', () async {
    await cubit.load();
    const failure = WorkoutServerUnavailableFailure();
    repository.failure = failure;
    await settle();
    states.clear();

    await cubit.refresh();
    await settle();

    final last = states.last as AnalyticsLoaded;
    expect(last.data.recentCompletions, hasLength(2));
    expect(last.refreshFailure, same(failure));
  });

  test('одинаковая ошибка refresh подряд будит экран оба раза', () async {
    await cubit.load();
    repository.failure = const WorkoutNetworkFailure();
    await settle();
    states.clear();

    await cubit.refresh();
    await cubit.refresh();
    await settle();

    expect(
      states.whereType<AnalyticsLoaded>().where((s) => s.refreshFailure != null),
      hasLength(2),
    );
  });

  test('refresh из ошибки работает как load', () async {
    repository.failure = const WorkoutNetworkFailure();
    await cubit.load();
    repository.failure = null;

    await cubit.refresh();
    await settle();

    expect(states.last, isA<AnalyticsLoaded>());
  });

  test('Future refresh завершается только после ответа, и на ошибке тоже', () async {
    await cubit.load();
    final gate = Completer<void>();
    repository.gate = gate;
    var done = false;

    final refreshing = cubit.refresh().then((_) => done = true);
    await settle();
    expect(done, isFalse);

    gate.complete();
    await refreshing;
    expect(done, isTrue);

    repository.gate = null;
    repository.failure = const WorkoutNetworkFailure();
    await expectLater(cubit.refresh(), completes);
  });

  test('кубит закрыт до ответа — emit не вызывается', () async {
    final gate = Completer<void>();
    repository.gate = gate;

    final loading = cubit.load();
    await cubit.close();
    gate.complete();

    await expectLater(loading, completes);
    expect(states.whereType<AnalyticsLoaded>(), isEmpty);
  });
}
