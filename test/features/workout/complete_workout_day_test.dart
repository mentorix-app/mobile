import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_target.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/usecases/complete_workout_day.dart';

import '../../helpers/workout_fakes.dart';

void main() {
  const target = CompletionTarget(
    assignmentId: 'a-1',
    programVersionId: 'v-1',
    completionCycleId: 'c-1',
    dayKey: 'day-1',
  );

  late FakeWorkoutRepository repository;
  late CompleteWorkoutDay completeDay;

  setUp(() {
    repository = FakeWorkoutRepository();
    completeDay = CompleteWorkoutDay(repository);
  });

  Future<void> call(String text) =>
      completeDay(trainerId: 'trainer-1', target: target, text: text);

  test('слепок и тренер уходят в репозиторий без изменений', () async {
    await call('Сделал 5x5');

    expect(repository.completeCalls, hasLength(1));
    final sent = repository.completeCalls.single;
    expect(sent.trainerId, 'trainer-1');
    expect(sent.target, target);
    expect(sent.text, 'Сделал 5x5');
  });

  test('текст обрезается по краям, переносы внутри остаются', () async {
    await call('  \n Раз\nдва \t');

    expect(repository.completeCalls.single.text, 'Раз\nдва');
  });

  test('запрещённые управляющие символы убираются', () async {
    await call('a\u0000b\u0007c');

    expect(repository.completeCalls.single.text, 'abc');
  });

  test('пустой текст и одни пробелы не уходят на сервер', () async {
    for (final text in ['', '   ', '\n\t ', '\u0000\u0001']) {
      await expectLater(
        call(text),
        throwsA(isA<WorkoutInvalidResultFailure>()),
        reason: '«$text»',
      );
    }
    expect(repository.completeCalls, isEmpty);
  });

  test('ровно 1000 символов уходит, 1001 — нет', () async {
    await call('я' * 1000);
    expect(repository.completeCalls, hasLength(1));

    await expectLater(call('я' * 1001), throwsA(isA<WorkoutInvalidResultFailure>()));
    expect(repository.completeCalls, hasLength(1));
  });

  test('эмодзи считаются как символы Unicode, а не как две единицы', () async {
    await call('💪' * 1000);
    expect(repository.completeCalls, hasLength(1));

    await expectLater(call('💪' * 1001), throwsA(isA<WorkoutInvalidResultFailure>()));
  });

  test('длина считается после обрезки пробелов', () async {
    await call('${' ' * 50}${'я' * 1000}${' ' * 50}');

    expect(repository.completeCalls.single.text.length, 1000);
  });

  test('ошибка репозитория пробрасывается как есть', () async {
    repository.completeFailure = const WorkoutProgramChangedFailure();

    await expectLater(call('ок'), throwsA(isA<WorkoutProgramChangedFailure>()));
  });

  test('ответ репозитория возвращается', () async {
    final result = await completeDay(trainerId: 't', target: target, text: 'ок');

    expect(result.dayKey, 'day-1');
    expect(result.resultText, 'ок');
  });
}
