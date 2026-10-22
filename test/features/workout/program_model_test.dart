import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/data/models/trainer_program_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';

import '../../helpers/talker_capture.dart';
import '../../helpers/workout_builders.dart';

const _trainerId = 'trainer-1';

TrainerProgram parse(Map<String, dynamic> json) =>
    TrainerProgramModel.fromJson(json, trainerId: _trainerId);

/// Программа с одной неделей и одним днём, чтобы проверять разбор по частям.
Map<String, dynamic> withDay(Map<String, dynamic> day) => {
  'assignment': {
    'assignment_id': 'a',
    'program_version_id': 'v',
    'completion_cycle_id': 'c',
  },
  'program': {
    'program_id': 'p',
    'name': 'P',
    'weeks': [
      {
        'id': 'w',
        'week_number': 1,
        'days': [day],
      },
    ],
  },
  'completed_days': <Object>[],
};

void main() {
  group('живой образец docs/samples/client_program.json', () {
    late TrainerProgram program;

    setUp(() => program = parse(loadProgramSample()));

    test('тренер, назначение, программа', () {
      expect(program.trainerId, _trainerId);
      expect(program.trainerName, 'Test free trainer');
      expect(program.hasProgram, isTrue);
      expect(program.assignment!.assignmentId, 'aac4e535-3af3-4224-bc8c-ce7396a487a2');
      expect(program.assignment!.programVersionId, '62ac5eb9-20bb-4f39-a388-868b95c8a504');
      expect(program.assignment!.completionCycleId, 'a68b74d6-9f1c-486f-8495-2228fe9d89d5');
      expect(program.assignment!.canMarkDays, isTrue);
      expect(program.assignment!.assignedAt, DateTime.utc(2026, 10, 20, 15, 24, 33, 85, 477));
      expect(program.program!.name, 'Mentorix Mobile Test');
      expect(program.program!.nameRu, 'Тест мобилки');
      expect(program.completedDayKeys, isEmpty);
    });

    test('две недели по семь дней', () {
      expect(program.weeks.map((w) => w.weekNumber), [1, 2]);
      expect(program.weeks.map((w) => w.days.length), [7, 7]);
    });

    test('дни отдыха: blocks пуст', () {
      final rest = [
        for (final w in program.weeks)
          for (final d in w.days)
            if (d.isRest) (w.weekNumber, d.dayNumber),
      ];

      expect(rest, [
        (1, 2), (1, 5), (1, 6), (1, 7),
        (2, 2), (2, 3), (2, 4), (2, 5), (2, 6), (2, 7),
      ]);
      expect(program.weeks.first.days[1].canComplete, isFalse);
    });

    test('день 1: два блока single без группы', () {
      final day = program.weeks.first.days.first;

      expect(day.dayKey, '0d879dc0-9365-43ab-8222-a95c6c477d24');
      expect(day.blocks.map((b) => b.type), [BlockType.single, BlockType.single]);
      expect(day.groupTypes, isEmpty);
      expect(day.exerciseCount, 2);
      expect(day.canComplete, isTrue);

      final squat = day.blocks.first.exercises.single;
      expect(squat.name, 'Back Squat');
      expect(squat.nameRu, 'Приседания со штангой на спине');
      expect(squat.sets, '5');
      expect(squat.reps, '5');
      expect(squat.instruction, '80 кг, отдых 2 мин');

      final press = day.blocks[1].exercises.single;
      expect(press.sets, '3');
      expect(press.reps, '8-12');
      expect(press.instruction, isEmpty);
      expect(day.blocks.first.instruction, isEmpty);
    });

    test('день 3: суперсет с инструкцией блока', () {
      final day = program.weeks.first.days[2];

      expect(day.groupTypes, [BlockType.superset]);
      expect(day.blocks.single.instruction, 'Без отдыха между упражнениями, 90 сек между кругами');
      expect(day.blocks.single.exercises.map((e) => e.name), ['Barbell Row', 'Barbell Biceps Curl']);
    });

    test('день 4: AMRAP — ключа sets нет, reps и инструкция есть', () {
      final block = program.weeks.first.days[3].blocks.single;

      expect(block.type, BlockType.amrap);
      expect(block.instruction, '12 минут, максимум раундов');
      expect(block.exercises.map((e) => e.sets), [null, null]);
      expect(block.exercises.map((e) => e.reps), ['15', '12']);
      expect(block.exercises.first.instruction, 'Считаем калории, не повторы');
    });

    test('неделя 2, день 1: EMOM, sets — число раундов', () {
      final block = program.weeks[1].days.first.blocks.single;

      expect(block.type, BlockType.emom);
      expect(block.exercises.map((e) => e.sets), ['10', '10']);
      expect(block.exercises.map((e) => e.reps), ['5', '8']);
    });

    test('прогресс: четыре тренировочных дня, ничего не отмечено', () {
      expect(program.totalTrainingDays, 4);
      expect(program.completedTrainingDays, 0);
      expect(program.isFinished, isFalse);
    });

    test('completed_days с сервера: чужой ключ в подсчёте не участвует', () {
      final json = loadProgramSample();
      json['completed_days'] = [
        {'day_key': '0d879dc0-9365-43ab-8222-a95c6c477d24'},
        {'day_key': 'ключ-удалённого-дня'},
      ];

      final parsed = parse(json);

      expect(parsed.completedDayKeys, hasLength(2));
      expect(parsed.completedTrainingDays, 1);
      expect(parsed.isCompleted(parsed.weeks.first.days.first), isTrue);
      expect(parsed.isCompleted(parsed.weeks.first.days[2]), isFalse);
    });

    test('день отдыха с ключом в completed_days не считается выполненным днём', () {
      final json = loadProgramSample();
      json['completed_days'] = [
        {'day_key': '037cac26-cec3-453e-ad80-cdab86242558'}, // день отдыха
      ];

      expect(parse(json).completedTrainingDays, 0);
    });
  });

  group('нет программы', () {
    test('assignment и program null — не ошибка', () {
      final program = parse({'assignment': null, 'program': null, 'completed_days': <Object>[]});

      expect(program.hasProgram, isFalse);
      expect(program.weeks, isEmpty);
      expect(program.completedDayKeys, isEmpty);
      expect(program.totalTrainingDays, 0);
      expect(program.isFinished, isFalse);
    });

    test('назначение без программы (и наоборот) — программы нет', () {
      expect(
        parse({'assignment': {'assignment_id': 'a'}, 'program': null}).hasProgram,
        isFalse,
      );
      expect(
        parse({'assignment': null, 'program': {'program_id': 'p', 'name': 'P'}}).hasProgram,
        isFalse,
      );
    });

    test('пустой объект: ни одного ключа — без исключения', () {
      final program = parse(<String, dynamic>{});

      expect(program.hasProgram, isFalse);
      expect(program.trainerName, '');
      expect(program.completedDayKeys, isEmpty);
    });
  });

  group('терпимость к полям', () {
    test('sets/reps: null, пусто, пробелы, число, отсутствие', () {
      final program = parse(
        withDay({
          'id': 'd',
          'day_key': 'k',
          'day_number': 1,
          'blocks': [
            {
              'id': 'b',
              'block_type': 'single',
              'exercises': [
                {'id': '1', 'exercise_name': 'A', 'sets': null, 'reps': ''},
                {'id': '2', 'exercise_name': 'B', 'sets': '  ', 'reps': 12},
                {'id': '3', 'exercise_name': 'C', 'sets': 3},
                {'id': '4', 'exercise_name': 'D'},
              ],
            },
          ],
        }),
      );

      final exercises = program.weeks.single.days.single.blocks.single.exercises;
      expect(exercises.map((e) => e.sets), [null, null, '3', null]);
      expect(exercises.map((e) => e.reps), [null, '12', null, null]);
    });

    test('name_ru и instruction: нет, null, пусто', () {
      final program = parse(
        withDay({
          'id': 'd',
          'day_key': 'k',
          'day_number': 1,
          'blocks': [
            {
              'id': 'b',
              'block_type': 'single',
              'instruction': null,
              'exercises': [
                {'id': '1', 'exercise_name': 'A', 'exercise_name_ru': null, 'instruction': null},
                {'id': '2', 'exercise_name': 'B'},
              ],
            },
          ],
        }),
      );

      final block = program.weeks.single.days.single.blocks.single;
      expect(block.instruction, '');
      expect(block.exercises.map((e) => e.nameRu), ['', '']);
      expect(block.exercises.map((e) => e.instruction), ['', '']);
    });

    test('неизвестный block_type — unknown, ключ пишется в debug-лог', () {
      final program = parse(
        withDay({
          'id': 'd',
          'day_key': 'k',
          'day_number': 1,
          'blocks': [
            {'id': 'b1', 'block_type': 'tabata_2030', 'exercises': [{'id': 'e', 'exercise_name': 'A'}]},
            {'id': 'b2', 'exercises': [{'id': 'e', 'exercise_name': 'B'}]},
            {'id': 'b3', 'block_type': null, 'exercises': [{'id': 'e', 'exercise_name': 'C'}]},
          ],
        }),
      );

      final day = program.weeks.single.days.single;
      expect(day.blocks.map((b) => b.type), [BlockType.unknown, BlockType.unknown, BlockType.unknown]);
      expect(day.groupTypes, [BlockType.unknown]);
      expect(loggedMessages().join('\n'), contains('unknown type "tabata_2030"'));
    });

    test('все 15 ключей API распознаются', () {
      const keys = [
        'single', 'emom', 'amrap', 'for_time', 'intervals', 'chipper', 'ladder',
        'death_by', 'superset', 'complex', 'skill_work', 'strength',
        'conditioning', 'gymnastics', 'weightlifting',
      ];

      final types = [for (final key in keys) BlockType.fromKey(key)];

      expect(types, isNot(contains(BlockType.unknown)));
      expect(types.toSet(), hasLength(15));
      expect([for (final t in types) t.key], keys);
      expect(BlockType.fromKey(null), BlockType.unknown);
      expect(BlockType.fromKey(''), BlockType.unknown);
      expect(BlockType.fromKey('SINGLE'), BlockType.unknown);
    });

    test('день без day_key: виден, но отметить нельзя', () {
      final day = parse(
        withDay({'id': 'd', 'day_number': 2, 'blocks': [
          {'id': 'b', 'block_type': 'single', 'exercises': [{'id': 'e', 'exercise_name': 'A'}]},
        ]}),
      ).weeks.single.days.single;

      expect(day.dayKey, '');
      expect(day.isTraining, isTrue);
      expect(day.canComplete, isFalse);
    });

    test('блок без упражнений остаётся, но день без упражнений не отметить', () {
      final day = parse(
        withDay({'id': 'd', 'day_key': 'k', 'day_number': 1, 'blocks': [
          {'id': 'b', 'block_type': 'emom', 'exercises': <Object>[]},
        ]}),
      ).weeks.single.days.single;

      expect(day.isRest, isFalse);
      expect(day.exerciseCount, 0);
      expect(day.canComplete, isFalse);
    });

    test('назначение без идентификаторов: программу видно, отметить нельзя', () {
      final json = withDay({'id': 'd', 'day_key': 'k', 'day_number': 1});
      json['assignment'] = {'assignment_id': 'a', 'completion_cycle_id': null};

      final parsed = parse(json);

      expect(parsed.hasProgram, isTrue);
      expect(parsed.assignment!.canMarkDays, isFalse);
      expect(parsed.assignment!.programVersionId, '');
    });

    test('неделя из трёх дней, имя тренера пустое, name_ru нет', () {
      final json = {
        'trainer_display_name': '   ',
        'assignment': {'assignment_id': 'a', 'program_version_id': 'v', 'completion_cycle_id': 'c'},
        'program': {
          'program_id': 'p',
          'name': 'Только английское',
          'weeks': [
            {
              'id': 'w',
              'week_number': 3,
              'days': [
                {'id': '1', 'day_key': 'k1', 'day_number': 1, 'blocks': <Object>[]},
                {'id': '2', 'day_key': 'k2', 'day_number': 2, 'blocks': <Object>[]},
                {'id': '3', 'day_key': 'k3', 'day_number': 3, 'blocks': <Object>[]},
              ],
            },
          ],
        },
        'completed_days': <Object>[],
      };

      final parsed = parse(json);

      expect(parsed.trainerName, '');
      expect(parsed.program!.nameRu, '');
      expect(parsed.weeks.single.weekNumber, 3);
      expect(parsed.weeks.single.days, hasLength(3));
    });

    test('неизвестные поля игнорируются', () {
      final json = loadProgramSample()
        ..['future_field'] = {'a': 1}
        ..['program'] = {
          ...(loadProgramSample()['program'] as Map<String, dynamic>),
          'category': 'new_category',
          'difficulty': null,
          'brand_new': true,
        };

      expect(parse(json).hasProgram, isTrue);
    });
  });

  group('порядок', () {
    test('недели, дни, блоки и упражнения — по sort_order', () {
      final json = {
        'assignment': {'assignment_id': 'a', 'program_version_id': 'v', 'completion_cycle_id': 'c'},
        'program': {
          'program_id': 'p',
          'name': 'P',
          'weeks': [
            {
              'id': 'w2', 'week_number': 2, 'sort_order': 2,
              'days': <Object>[],
            },
            {
              'id': 'w1', 'week_number': 1, 'sort_order': 1,
              'days': [
                {'id': 'd2', 'day_number': 2, 'sort_order': 2, 'blocks': <Object>[]},
                {
                  'id': 'd1', 'day_number': 1, 'sort_order': 1,
                  'blocks': [
                    {
                      'id': 'b2', 'block_type': 'single', 'sort_order': 2,
                      'exercises': [
                        {'id': 'e2', 'exercise_name': 'Второе', 'sort_order': 2},
                        {'id': 'e1', 'exercise_name': 'Первое', 'sort_order': 1},
                      ],
                    },
                    {'id': 'b1', 'block_type': 'superset', 'sort_order': 1, 'exercises': <Object>[]},
                  ],
                },
              ],
            },
          ],
        },
      };

      final parsed = parse(json);

      expect(parsed.weeks.map((w) => w.weekNumber), [1, 2]);
      final days = parsed.weeks.first.days;
      expect(days.map((d) => d.dayNumber), [1, 2]);
      expect(days.first.blocks.map((b) => b.id), ['b1', 'b2']);
      expect(days.first.blocks.last.exercises.map((e) => e.name), ['Первое', 'Второе']);
    });

    test('равный или отсутствующий sort_order — порядок ответа сохраняется', () {
      final json = withDay({'id': 'd', 'day_key': 'k', 'day_number': 1, 'blocks': [
        {'id': 'x', 'block_type': 'single', 'exercises': <Object>[]},
        {'id': 'y', 'block_type': 'single', 'exercises': <Object>[]},
        {'id': 'z', 'block_type': 'single', 'exercises': <Object>[]},
      ]});

      final ids = parse(json).weeks.single.days.single.blocks.map((b) => b.id);

      expect(ids, ['x', 'y', 'z']);
    });
  });

  group('битые данные не роняют разбор', () {
    test('элементы, не объекты, пропускаются; в лог идёт счётчик, не содержимое', () {
      final json = {
        'assignment': {'assignment_id': 'a', 'program_version_id': 'v', 'completion_cycle_id': 'c'},
        'program': {
          'program_id': 'p',
          'name': 'P',
          'weeks': [
            'секретная строка',
            {
              'id': 'w', 'week_number': 1,
              'days': [
                7,
                {'id': 'd', 'day_key': 'k', 'day_number': 1, 'blocks': [null, 'x']},
              ],
            },
          ],
        },
        'completed_days': ['k', null, {'day_key': 'k'}, {'day_key': ''}, {'x': 1}],
      };

      final parsed = parse(json);

      expect(parsed.weeks, hasLength(1));
      expect(parsed.weeks.single.days, hasLength(1));
      expect(parsed.weeks.single.days.single.isRest, isTrue);
      expect(parsed.completedDayKeys, {'k'});
      final log = loggedMessages().join('\n');
      expect(log, contains('skipped weeks'));
      expect(log, isNot(contains('секретная')));
    });

    test('weeks / days / blocks не списки — пустые', () {
      final json = {
        'assignment': {'assignment_id': 'a', 'program_version_id': 'v', 'completion_cycle_id': 'c'},
        'program': {'program_id': 'p', 'name': 'P', 'weeks': {'a': 1}},
        'completed_days': 'nope',
      };

      final parsed = parse(json);

      expect(parsed.hasProgram, isTrue);
      expect(parsed.weeks, isEmpty);
      expect(parsed.completedDayKeys, isEmpty);
    });

    test('инструкция в 5000 символов сохраняется целиком, управляющие символы убираются', () {
      final long = 'а' * 5000;
      final json = withDay({'id': 'd', 'day_key': 'k', 'day_number': 1, 'blocks': [
        {
          'id': 'b',
          'block_type': 'complex',
          'instruction': long,
          'exercises': [
            {'id': 'e', 'exercise_name': 'A', 'instruction': 'раз\u0000два\nтри'},
          ],
        },
      ]});

      final block = parse(json).weeks.single.days.single.blocks.single;

      expect(block.instruction.length, 5000);
      expect(block.exercises.single.instruction, 'раздва\nтри');
    });

    test('название программы в 1000 символов не обрезается моделью', () {
      final json = withDay({'id': 'd', 'day_key': 'k', 'day_number': 1});
      (json['program']! as Map<String, dynamic>)['name'] = 'Н' * 1000;

      expect(parse(json).program!.name.length, 1000);
    });
  });
}
