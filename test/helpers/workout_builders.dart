import 'dart:convert';
import 'dart:io';

import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/program.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_assignment.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_block.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_day.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_exercise.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_week.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_program.dart';

/// Живой образец `GET /client/trainers/{id}/program` из `docs/samples/`.
Map<String, dynamic> loadProgramSample() =>
    jsonDecode(File('docs/samples/client_program.json').readAsStringSync())
        as Map<String, dynamic>;

ProgramExercise exercise(String name, {String? sets, String? reps, String instruction = ''}) =>
    ProgramExercise(
      id: 'ex-$name',
      name: name,
      sets: sets,
      reps: reps,
      instruction: instruction,
    );

ProgramBlock block(
  BlockType type, {
  List<ProgramExercise>? exercises,
  String instruction = '',
}) => ProgramBlock(
  id: 'b-${type.key}',
  type: type,
  instruction: instruction,
  exercises: exercises ?? [exercise('Squat')],
);

/// Тренировочный день с одним упражнением, если блоки не заданы.
ProgramDay trainingDay(int number, {String? key, List<ProgramBlock>? blocks}) =>
    ProgramDay(
      id: 'd-$number',
      dayKey: key ?? 'key-$number',
      dayNumber: number,
      blocks: blocks ?? [block(BlockType.single)],
    );

ProgramDay restDay(int number, {String? key}) => ProgramDay(
  id: 'd-$number',
  dayKey: key ?? 'key-$number',
  dayNumber: number,
);

ProgramWeek week(int number, List<ProgramDay> days) =>
    ProgramWeek(id: 'w-$number', weekNumber: number, days: days);

/// Программа с назначением. Идентификаторы назначения — константы теста.
TrainerProgram trainerProgram(
  List<ProgramWeek> weeks, {
  Set<String> completed = const {},
  String name = 'Mentorix-app',
  String nameRu = '',
  String trainerName = 'Aziz Geidar',
  String trainerId = 'aziz',
}) => TrainerProgram(
  trainerId: trainerId,
  trainerName: trainerName,
  assignment: const ProgramAssignment(
    assignmentId: 'assignment-1',
    programVersionId: 'version-1',
    completionCycleId: 'cycle-1',
  ),
  program: Program(id: 'program-1', name: name, nameRu: nameRu, weeks: weeks),
  completedDayKeys: completed,
);

/// Тестовая программа stage: неделя 1, тренировочные дни 1, 2 и 4, остальные —
/// отдых. День 1: Back Squat (single), Superset, Arnold Press; день 2: EMOM;
/// день 4: AMRAP.
TrainerProgram stageProgram({Set<String> completed = const {}}) => trainerProgram(
  [
    week(1, [
      trainingDay(
        1,
        key: 'day-1',
        blocks: [
          block(BlockType.single, exercises: [exercise('Back Squat', sets: '5', reps: '5')]),
          block(
            BlockType.superset,
            exercises: [
              exercise('Bench Press', sets: '4', reps: '10'),
              exercise('Barbell Row', sets: '4', reps: '12'),
            ],
          ),
          block(BlockType.single, exercises: [exercise('Arnold Press', sets: '3')]),
        ],
      ),
      trainingDay(
        2,
        key: 'day-2',
        blocks: [
          block(
            BlockType.emom,
            exercises: [
              exercise('Kettlebell Swing', sets: '5', reps: '15'),
              exercise('Burpee', sets: '5', reps: '10'),
            ],
          ),
        ],
      ),
      restDay(3, key: 'day-3'),
      trainingDay(
        4,
        key: 'day-4',
        blocks: [
          block(
            BlockType.amrap,
            exercises: [
              exercise('Assault Bike', reps: '12'),
              exercise('Burpee Box Jump Over', reps: '8'),
            ],
          ),
        ],
      ),
      restDay(5, key: 'day-5'),
      restDay(6, key: 'day-6'),
      restDay(7, key: 'day-7'),
    ]),
  ],
  completed: completed,
);
