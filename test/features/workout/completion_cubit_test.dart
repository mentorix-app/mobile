import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_assignment.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';
import 'package:mentorix_app/features/workout/domain/usecases/complete_workout_day.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/completion_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/completion_state.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_state.dart';

import '../../helpers/workout_builders.dart';
import '../../helpers/workout_fakes.dart';

void main() {
  late FakeWorkoutRepository repository;
  late ProgramCubit program;
  late CompletionCubit cubit;
  late List<CompletionState> states;
  late StreamSubscription<CompletionState> subscription;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Сервер записал отметку: день попадает в `completed_days`.
  void serverMarksDone() {
    repository.onCompleted = (target, _) {
      final current = repository.programResult;
      repository.programResult = TrainerProgram(
        trainerId: current.trainerId,
        trainerName: current.trainerName,
        assignment: current.assignment,
        program: current.program,
        completedDayKeys: {...current.completedDayKeys, target.dayKey},
      );
    };
  }

  /// Тренер переназначил программу: новая версия и цикл, те же дни.
  TrainerProgram reassigned({
    Set<String> completed = const {},
    List<int>? keepDays,
  }) {
    final base = stageProgram(completed: completed);
    return TrainerProgram(
      trainerId: base.trainerId,
      trainerName: base.trainerName,
      assignment: const ProgramAssignment(
        assignmentId: 'assignment-2',
        programVersionId: 'version-2',
        completionCycleId: 'cycle-2',
      ),
      program: base.program,
      completedDayKeys: completed,
    );
  }

  Future<CompletionCubit> openFor(String dayKey) async {
    program = ProgramCubit('aziz', repository);
    await program.load();
    final created = CompletionCubit(
      program: program,
      dayKey: dayKey,
      completeDay: CompleteWorkoutDay(repository),
    );
    states = [];
    subscription = created.stream.listen(states.add);
    return created;
  }

  setUp(() async {
    repository = FakeWorkoutRepository()..programResult = stageProgram();
    cubit = await openFor('day-1');
  });

  tearDown(() async {
    await subscription.cancel();
    await cubit.close();
    await program.close();
  });

  group('успешная отметка', () {
    test('идёт слепок из загруженной программы и подготовленный текст', () async {
      serverMarksDone();

      await cubit.submit('  Сделал 5x5  ');
      await settle();

      expect(repository.completeCalls, hasLength(1));
      final call = repository.completeCalls.single;
      expect(call.trainerId, 'aziz');
      expect(call.target.assignmentId, 'assignment-1');
      expect(call.target.programVersionId, 'version-1');
      expect(call.target.completionCycleId, 'cycle-1');
      expect(call.target.dayKey, 'day-1');
      expect(call.text, 'Сделал 5x5');
    });

    test('отправка → программа перезагружена → Done', () async {
      serverMarksDone();
      final callsBefore = repository.programCalls;

      await cubit.submit('ок');
      await settle();

      expect(states, [const CompletionSubmitting(), const CompletionDone()]);
      expect(repository.programCalls, callsBefore + 1);
    });

    test('выполненность берётся с сервера: день отмечен только после обновления', () async {
      serverMarksDone();
      final before = (program.state as ProgramLoaded).data;
      expect(before.isCompleted(before.locate('day-1')!.day), isFalse);

      await cubit.submit('ок');

      final after = (program.state as ProgramLoaded).data;
      expect(after.isCompleted(after.locate('day-1')!.day), isTrue);
      expect(after.completedTrainingDays, 1);
    });

    test('тихое обновление: ошибки обновления на экран не идут', () async {
      serverMarksDone();

      await cubit.submit('ок');

      final state = program.state as ProgramLoaded;
      expect(state.refreshFailure, isNull);
    });

    test('после успеха повторная отправка игнорируется', () async {
      serverMarksDone();
      await cubit.submit('ок');

      await cubit.submit('ещё раз');

      expect(repository.completeCalls, hasLength(1));
    });

    test('обновление не удалось после 201: отметка сохранена, Done с пометкой', () async {
      repository.onCompleted = (_, _) =>
          repository.programFailure = const WorkoutNetworkFailure();

      await cubit.submit('ок');
      await settle();

      expect(states, [
        const CompletionSubmitting(),
        const CompletionDone(refreshFailed: true),
      ]);
      expect(repository.completeCalls, hasLength(1), reason: 'повторной отметки нет');
      // Показанные данные остались, экран не превратился в ошибку.
      expect(program.state, isA<ProgramLoaded>());
      expect((program.state as ProgramLoaded).refreshFailure, isNull);
    });

    test('в completed_days дня всё нет: отметка записана, экран обновится позже', () async {
      // Сервер ответил 201, но свежая программа день не содержит.
      await cubit.submit('ок');
      await settle();

      expect(states.last, const CompletionDone(refreshFailed: true));
      expect(repository.programCalls, 3, reason: 'загрузка + две попытки обновления');
    });

    test('устаревшее обновление, начатое до отметки, не обманывает', () async {
      serverMarksDone();
      final gate = Completer<void>();
      repository.programGate = gate;
      final stale = program.refresh(silent: true); // уйдёт со старыми данными
      await settle();

      final submitting = cubit.submit('ок');
      await settle();
      repository.programGate = null;
      gate.complete();
      await submitting;
      await stale;

      final data = (program.state as ProgramLoaded).data;
      expect(data.isCompleted(data.locate('day-1')!.day), isTrue);
      expect(states.last, const CompletionDone());
    });
  });

  group('защита от повторов', () {
    test('нажали дважды, пока идёт отправка — запрос один', () async {
      serverMarksDone();
      final gate = Completer<void>();
      repository.completeGate = gate;

      final first = cubit.submit('ок');
      await settle();
      final second = cubit.submit('ок');
      final third = cubit.submit('ок');
      await settle();

      expect(cubit.state, const CompletionSubmitting());
      expect(repository.completeCalls, hasLength(1));

      gate.complete();
      await Future.wait([first, second, third]);
      await settle();

      expect(repository.completeCalls, hasLength(1));
      expect(states.last, const CompletionDone());
    });
  });

  group('текст результата', () {
    test('пустой и из одних пробелов не уходит: Failed(InvalidResult)', () async {
      for (final text in ['', '   \n']) {
        await cubit.submit(text);
        await settle();

        expect(states.last, isA<CompletionFailed>());
        expect((states.last as CompletionFailed).failure, isA<WorkoutInvalidResultFailure>());
      }
      expect(repository.completeCalls, isEmpty);
    });

    test('после «пусто» можно отправить нормальный текст', () async {
      serverMarksDone();
      await cubit.submit('');

      await cubit.submit('ок');

      expect(repository.completeCalls.single.text, 'ок');
      expect(cubit.state, const CompletionDone());
    });

    test('длиннее 1000 символов не уходит', () async {
      await cubit.submit('я' * 1001);

      expect((cubit.state as CompletionFailed).failure, isA<WorkoutInvalidResultFailure>());
      expect(repository.completeCalls, isEmpty);
    });
  });

  group('409 program_changed', () {
    setUp(() => repository.completeFailure = const WorkoutProgramChangedFailure());

    test('программа перезагружена, новый слепок, запрос сам не повторяется', () async {
      repository.onCompleted = null;
      repository.programResult = reassigned();

      await cubit.submit('текст');
      await settle();

      expect(states, [
        const CompletionSubmitting(),
        const CompletionIdle(programChanged: true),
      ]);
      expect(repository.completeCalls, hasLength(1), reason: 'ничего не переотправлено');
      final data = (program.state as ProgramLoaded).data;
      expect(data.assignment!.completionCycleId, 'cycle-2');
    });

    test('следующая отправка (по решению пользователя) идёт с новыми идентификаторами', () async {
      repository.programResult = reassigned();
      await cubit.submit('текст');
      repository.completeFailure = null;
      serverMarksDone();

      await cubit.submit('текст');

      expect(repository.completeCalls, hasLength(2));
      final first = repository.completeCalls.first.target;
      final second = repository.completeCalls.last.target;
      expect(first.completionCycleId, 'cycle-1');
      expect(first.programVersionId, 'version-1');
      expect(first.assignmentId, 'assignment-1');
      expect(second.completionCycleId, 'cycle-2');
      expect(second.programVersionId, 'version-2');
      expect(second.assignmentId, 'assignment-2');
      expect(second.dayKey, 'day-1');
      expect(cubit.state, const CompletionDone());
    });

    test('день пропал из новой программы — экран закрывается, dayGone', () async {
      repository.programResult = trainerProgram([
        week(1, [trainingDay(1, key: 'другой-день')]),
      ]);

      await cubit.submit('текст');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.dayGone));
      expect(repository.completeCalls, hasLength(1));
    });

    test('назначения больше нет — notAssigned', () async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');

      await cubit.submit('текст');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.notAssigned));
    });

    test('день в новой программе уже выполнен — alreadyCompleted', () async {
      repository.programResult = reassigned(completed: {'day-1'});

      await cubit.submit('текст');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.alreadyCompleted));
    });

    test('день стал днём отдыха — dayGone', () async {
      repository.programResult = trainerProgram([
        week(1, [restDay(1, key: 'day-1')]),
      ]);

      await cubit.submit('текст');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.dayGone));
    });

    test('свежую программу получить не удалось: Failed, слепок прежний, повтор возможен', () async {
      repository.programFailure = const WorkoutNetworkFailure();

      await cubit.submit('текст');

      expect((cubit.state as CompletionFailed).failure, isA<WorkoutProgramChangedFailure>());

      // Связь вернулась; сервер по-прежнему ждёт свежих идентификаторов.
      repository.programFailure = null;
      repository.programResult = reassigned();
      await cubit.submit('текст');

      expect(cubit.state, const CompletionIdle(programChanged: true));
      expect(repository.completeCalls, hasLength(2));
    });

    test('изменение происходит дважды подряд — оба раза пользователь предупреждён', () async {
      repository.programResult = reassigned();
      await cubit.submit('текст');
      expect(cubit.state, const CompletionIdle(programChanged: true));

      repository.programResult = TrainerProgram(
        trainerId: 'aziz',
        assignment: const ProgramAssignment(
          assignmentId: 'assignment-3',
          programVersionId: 'version-3',
          completionCycleId: 'cycle-3',
        ),
        program: stageProgram().program,
      );
      await cubit.submit('текст');
      await settle();

      expect(
        states.where((s) => s == const CompletionIdle(programChanged: true)),
        hasLength(2),
      );
      expect(repository.completeCalls.last.target.completionCycleId, 'cycle-2');
    });
  });

  group('другие ответы сервера', () {
    test('409 workout_already_completed: обновить программу и закрыться', () async {
      repository.completeFailure = const WorkoutAlreadyCompletedFailure();
      repository.programResult = stageProgram(completed: {'day-1'});
      final callsBefore = repository.programCalls;

      await cubit.submit('ок');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.alreadyCompleted));
      expect(repository.programCalls, callsBefore + 1);
      final data = (program.state as ProgramLoaded).data;
      expect(data.isCompleted(data.locate('day-1')!.day), isTrue);
    });

    test('404 day_not_found: обновить программу и закрыться', () async {
      repository.completeFailure = const WorkoutDayNotFoundFailure();
      final callsBefore = repository.programCalls;

      await cubit.submit('ок');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.dayGone));
      expect(repository.programCalls, callsBefore + 1);
    });

    test('обрыв связи: Failed, потом повтор; если запрос дошёл — 409 «уже отмечен»', () async {
      repository.completeFailure = const WorkoutNetworkFailure();
      await cubit.submit('ок');
      expect((cubit.state as CompletionFailed).failure, isA<WorkoutNetworkFailure>());

      // Ответ потерялся, а отметка на сервере была: повтор получает 409.
      repository.completeFailure = const WorkoutAlreadyCompletedFailure();
      repository.programResult = stageProgram(completed: {'day-1'});
      await cubit.submit('ок');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.alreadyCompleted));
      expect(repository.completeCalls, hasLength(2));
    });

    test('429, 503, 403, 422: Failed, ничего не повторяется само', () async {
      for (final failure in <WorkoutFailure>[
        const WorkoutTooManyRequestsFailure(),
        const WorkoutServerUnavailableFailure(),
        const WorkoutNotLinkedFailure(),
        const WorkoutBlockedFailure(),
        const WorkoutUnknownFailure(),
      ]) {
        repository.completeFailure = failure;
        final before = repository.completeCalls.length;

        await cubit.submit('ок');

        expect((cubit.state as CompletionFailed).failure, same(failure));
        expect(repository.completeCalls.length, before + 1);
      }
    });

    test('после Failed поле разблокировано: следующая отправка работает', () async {
      repository.completeFailure = const WorkoutServerUnavailableFailure();
      await cubit.submit('ок');
      repository.completeFailure = null;
      serverMarksDone();

      await cubit.submit('ок');

      expect(cubit.state, const CompletionDone());
    });
  });

  group('экран открыт для дня, который отметить нельзя', () {
    test('день уже выполнен — Closed(alreadyCompleted), отправка игнорируется', () async {
      repository.programResult = stageProgram(completed: {'day-1'});
      await subscription.cancel();
      await program.close();
      cubit = await openFor('day-1');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.alreadyCompleted));
      await cubit.submit('ок');
      expect(repository.completeCalls, isEmpty);
    });

    test('день отдыха и неизвестный день — Closed(dayGone)', () async {
      for (final key in ['day-3', 'нет-такого']) {
        await subscription.cancel();
        await program.close();
        cubit = await openFor(key);

        expect(cubit.state, const CompletionClosed(CompletionCloseReason.dayGone), reason: key);
      }
    });

    test('программа не назначена — Closed(notAssigned)', () async {
      repository.programResult = const TrainerProgram(trainerId: 'aziz');
      await subscription.cancel();
      await program.close();
      cubit = await openFor('day-1');

      expect(cubit.state, const CompletionClosed(CompletionCloseReason.notAssigned));
    });
  });

  test('кубит закрыт до ответа — emit не вызывается и ничего не падает', () async {
    final gate = Completer<void>();
    repository.completeGate = gate;

    final submitting = cubit.submit('ок');
    await settle();
    await cubit.close();
    gate.complete();

    await expectLater(submitting, completes);
    expect(states.whereType<CompletionDone>(), isEmpty);
  });
}
