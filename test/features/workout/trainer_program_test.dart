import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';
import 'package:mentorix_app/features/workout/domain/usecases/find_next_workout_day.dart';

import '../../helpers/workout_builders.dart';

void main() {
  const find = FindNextWorkoutDay();

  group('выполненность и прогресс — только по completed_days', () {
    test('тестовая программа stage: три тренировочных дня, четыре отдыха', () {
      final program = stageProgram();

      expect(program.totalTrainingDays, 3);
      expect(program.completedTrainingDays, 0);
      expect(program.weeks.single.days.where((d) => d.isRest).map((d) => d.dayNumber), [3, 5, 6, 7]);
      expect(program.isFinished, isFalse);
    });

    test('ключ из completed_days делает день выполненным, остальные нет', () {
      final program = stageProgram(completed: {'day-1'});
      final days = program.weeks.single.days;

      expect(program.isCompleted(days[0]), isTrue);
      expect(program.isCompleted(days[1]), isFalse);
      expect(program.completedTrainingDays, 1);
    });

    test('день, отмеченный в боте, появляется с новым ответом сервера', () {
      final before = stageProgram();
      final after = stageProgram(completed: {'day-2'});

      expect(before.isCompleted(before.weeks.single.days[1]), isFalse);
      expect(after.isCompleted(after.weeks.single.days[1]), isTrue);
    });

    test('ключ несуществующего дня и ключ дня отдыха не считаются', () {
      final program = stageProgram(completed: {'удалённый-день', 'day-3'});

      expect(program.completedTrainingDays, 0);
    });

    test('день без ключа выполненным не бывает', () {
      final day = trainingDay(1, key: '');
      final program = trainerProgram([week(1, [day])], completed: {''});

      expect(program.isCompleted(day), isFalse);
    });

    test('все тренировочные дни выполнены — программа пройдена', () {
      final program = stageProgram(completed: {'day-1', 'day-2', 'day-4', 'чужой'});

      expect(program.completedTrainingDays, 3);
      expect(program.isFinished, isTrue);
    });

    test('без тренировочных дней программа «пройденной» не бывает', () {
      final program = trainerProgram([week(1, [restDay(1), restDay(2)])]);

      expect(program.totalTrainingDays, 0);
      expect(program.isFinished, isFalse);
    });

    test('нет назначения или программы — hasProgram false', () {
      expect(const TrainerProgram(trainerId: 't').hasProgram, isFalse);
      expect(stageProgram().hasProgram, isTrue);
    });
  });

  group('день', () {
    test('отдых: blocks пуст; тренировка: хотя бы один блок', () {
      expect(restDay(1).isRest, isTrue);
      expect(restDay(1).isTraining, isFalse);
      expect(restDay(1).canComplete, isFalse);
      expect(trainingDay(1).isTraining, isTrue);
      expect(trainingDay(1).canComplete, isTrue);
    });

    test('groupTypes: порядок появления, без повторов, single не входит', () {
      final day = trainingDay(1, blocks: [
        block(BlockType.single),
        block(BlockType.emom),
        block(BlockType.superset),
        block(BlockType.emom),
        block(BlockType.single),
      ]);

      expect(day.groupTypes, [BlockType.emom, BlockType.superset]);
      expect(day.exerciseCount, 5);
    });

    test('день без ключа или без упражнений не отмечается', () {
      expect(trainingDay(1, key: '').canComplete, isFalse);
      expect(trainingDay(1, blocks: [block(BlockType.emom, exercises: [])]).canComplete, isFalse);
    });
  });

  group('FindNextWorkoutDay', () {
    test('ничего не выполнено — первый тренировочный день', () {
      final next = find(stageProgram())!;

      expect(next.weekNumber, 1);
      expect(next.day.dayNumber, 1);
    });

    test('дни можно проходить в любом порядке: берётся первый невыполненный', () {
      final next = find(stageProgram(completed: {'day-2'}))!;
      expect(next.day.dayNumber, 1);

      final afterFirst = find(stageProgram(completed: {'day-1', 'day-2'}))!;
      expect(afterFirst.day.dayNumber, 4);
    });

    test('дни отдыха пропускаются', () {
      final program = trainerProgram([week(1, [restDay(1), restDay(2), trainingDay(3)])]);

      expect(find(program)!.day.dayNumber, 3);
    });

    test('переходит на следующую неделю', () {
      final program = trainerProgram(
        [
          week(1, [trainingDay(1, key: 'a'), restDay(2)]),
          week(2, [restDay(1), trainingDay(2, key: 'b')]),
        ],
        completed: {'a'},
      );

      final next = find(program)!;
      expect(next.weekNumber, 2);
      expect(next.day.dayNumber, 2);
    });

    test('всё выполнено, дней нет или программы нет — null', () {
      expect(find(stageProgram(completed: {'day-1', 'day-2', 'day-4'})), isNull);
      expect(find(trainerProgram([week(1, [restDay(1)])])), isNull);
      expect(find(const TrainerProgram(trainerId: 't')), isNull);
    });

    test('ключ чужого дня следующий день не меняет', () {
      expect(find(stageProgram(completed: {'чужой'}))!.day.dayNumber, 1);
    });
  });
}
