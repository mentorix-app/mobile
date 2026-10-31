import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/workout/data/models/client_analytics_model.dart';
import 'package:mentorix_app/features/workout/domain/entities/client_analytics.dart';

import '../../helpers/talker_capture.dart';
import '../../helpers/workout_builders.dart';

ClientAnalytics parse(Map<String, dynamic> json) => ClientAnalyticsModel.fromJson(json);

void main() {
  group('живой образец docs/samples/client_analytics.json (две отметки)', () {
    late ClientAnalytics analytics;

    setUp(() => analytics = parse(loadAnalyticsSample()));

    test('текущая программа и прогресс: 2 из 3, 66.7 %', () {
      final assignment = analytics.currentAssignment!;

      expect(assignment.programName, 'Mentorix-app');
      expect(assignment.programNameRu, 'Mentorix-app (тест)');
      expect(assignment.completedDays, 2);
      expect(assignment.totalTrainingDays, 3);
      expect(assignment.completionPercent, 66.7);
      expect(assignment.weeks, [
        const WeekProgress(weekNumber: 1, totalDays: 3, completedDays: 2),
      ]);
    });

    test('активность за всё время', () {
      final activity = analytics.activity;

      expect(activity.totalCompletions, 2);
      expect(activity.completionsLast7Days, 2);
      expect(activity.completionsLast30Days, 2);
      expect(activity.weekStreak, 1);
      expect(activity.firstCompletedAt, DateTime.utc(2026, 10, 28, 16, 31, 18, 234, 372));
      expect(activity.lastCompletedAt, DateTime.utc(2026, 10, 28, 16, 33, 4, 675, 113));
      expect(activity.byProgram.single.programName, 'Mentorix-app');
      expect(activity.byProgram.single.programNameRu, 'Mentorix-app (тест)');
      expect(activity.byProgram.single.totalCompletions, 2);
    });

    test('отметки: порядок сервера (новые первыми), снимок недели и дня', () {
      final records = analytics.recentCompletions;

      expect(records.map((r) => r.dayNumber), [2, 1]);
      expect(records.map((r) => r.weekNumber), [1, 1]);
      expect(records.first.id, 'a3307c8f-d2ae-4876-befe-e00aa2ead728');
      expect(records.first.completedAt, DateTime.utc(2026, 10, 28, 16, 33, 4, 675, 113));
      expect(records.first.programName, 'Mentorix-app');
      expect(records.first.programNameRu, 'Mentorix-app (тест)');
    });

    test('текст клиента', () {
      expect(analytics.recentCompletions.map((r) => r.resultText), ['Kkk', 'Sssss']);
    });

    test('ответ тренера у первой отметки, у второй пустой comments', () {
      final first = analytics.recentCompletions.first.comments;
      final second = analytics.recentCompletions.last.comments;

      expect(first, hasLength(1));
      expect(first.single.id, 'da0d50ca-936c-4022-babf-2c8a70cb3012');
      expect(first.single.text, 'Хорошая работа! В следующий раз напиши, с каким весом делал свинги.');
      expect(first.single.createdAt, DateTime.utc(2026, 10, 29, 13, 28, 2, 890, 307));
      expect(second, isEmpty);
    });

    test('is_current_cycle, expires_at, client и trainer не нужны модели', () {
      // Просто не падает и ничего из этого в модель не попадает.
      expect(analytics.recentCompletions, hasLength(2));
    });
  });

  group('образец до первой отметки (client_analytics_empty.json)', () {
    test('нули, пустые списки, null-даты; completion_percent целым 0', () {
      final analytics = parse(loadAnalyticsSample('client_analytics_empty.json'));

      expect(analytics.currentAssignment!.completedDays, 0);
      expect(analytics.currentAssignment!.totalTrainingDays, 3);
      expect(analytics.currentAssignment!.completionPercent, 0);
      expect(analytics.currentAssignment!.completionPercent, isA<double>());
      expect(analytics.activity.totalCompletions, 0);
      expect(analytics.activity.firstCompletedAt, isNull);
      expect(analytics.activity.lastCompletedAt, isNull);
      expect(analytics.activity.byProgram, isEmpty);
      expect(analytics.recentCompletions, isEmpty);
    });
  });

  group('completion_percent', () {
    ClientAnalytics withPercent(Object? value, {int done = 1, int total = 4}) => parse({
      'current_assignment': {
        'program_name': 'P',
        'progress': {
          'completed_days': done,
          'total_training_days': total,
          'completion_percent': ?value,
        },
      },
    });

    test('целое, дробное и сотня читаются как число', () {
      expect(withPercent(0).currentAssignment!.completionPercent, 0);
      expect(withPercent(33.3).currentAssignment!.completionPercent, 33.3);
      expect(withPercent(100).currentAssignment!.completionPercent, 100);
      expect(withPercent(66.7).currentAssignment!.completionPercent, 66.7);
    });

    test('нет значения — считается от дней', () {
      expect(withPercent(null).currentAssignment!.completionPercent, 25);
      expect(withPercent(null, done: 0, total: 0).currentAssignment!.completionPercent, 0);
      expect(withPercent(null, done: 9, total: 3).currentAssignment!.completionPercent, 100);
    });

    test('значение не числом — тоже считается от дней', () {
      expect(withPercent('много').currentAssignment!.completionPercent, 25);
    });
  });

  group('терпимость к полям', () {
    test('пустой объект и отсутствие всего', () {
      final analytics = parse(<String, dynamic>{});

      expect(analytics.currentAssignment, isNull);
      expect(analytics.activity.totalCompletions, 0);
      expect(analytics.recentCompletions, isEmpty);
    });

    test('current_assignment: null — программы нет', () {
      expect(parse({'current_assignment': null}).currentAssignment, isNull);
    });

    test('прогресс и недели отсутствуют — нули', () {
      final assignment = parse({
        'current_assignment': {'program_name': 'P'},
      }).currentAssignment!;

      expect(assignment.completedDays, 0);
      expect(assignment.totalTrainingDays, 0);
      expect(assignment.weeks, isEmpty);
    });

    test('display_name пустой, идентификаторы любого вида, лишние поля', () {
      final analytics = parse({
        'client': {'client_user_id': 'не-uuid', 'display_name': ''},
        'trainer': {'trainer_id': 'тоже-нет', 'display_name': ''},
        'future': {'x': 1},
        'recent_completions': [
          {'id': 'x', 'new_field': true},
        ],
      });

      expect(analytics.recentCompletions.single.id, 'x');
    });

    test('result_text: пусто, отсутствует, null, управляющие символы', () {
      final records = parse({
        'recent_completions': [
          {'id': '1', 'result_text': ''},
          {'id': '2'},
          {'id': '3', 'result_text': null},
          {'id': '4', 'result_text': '  a\u0000b\u0007c\nd  '},
        ],
      }).recentCompletions;

      expect(records.map((r) => r.resultText), ['', '', '', 'abc\nd']);
    });

    test('переносы строк в результате и ответе сохраняются', () {
      final record = parse({
        'recent_completions': [
          {
            'id': '1',
            'result_text': 'Раз\nдва\r\nтри',
            'comments': [
              {'id': 'c', 'text': 'Строка 1\nСтрока 2'},
            ],
          },
        ],
      }).recentCompletions.single;

      expect(record.resultText, 'Раз\nдва\r\nтри');
      expect(record.comments.single.text, 'Строка 1\nСтрока 2');
    });

    test('comments: нет, null, не список, мусор внутри', () {
      final records = parse({
        'recent_completions': [
          {'id': '1'},
          {'id': '2', 'comments': null},
          {'id': '3', 'comments': 'нет'},
          {
            'id': '4',
            'comments': [
              7,
              null,
              {'id': 'k', 'text': 'ответ', 'created_at': 'вчера'},
            ],
          },
        ],
      }).recentCompletions;

      expect(records.map((r) => r.comments.length), [0, 0, 0, 1]);
      expect(records.last.comments.single.text, 'ответ');
      expect(records.last.comments.single.createdAt, isNull);
    });

    test('несколько ответов — порядок сервера', () {
      final comments = parse({
        'recent_completions': [
          {
            'id': '1',
            'comments': [
              {'id': 'a', 'text': 'первый'},
              {'id': 'b', 'text': 'второй'},
            ],
          },
        ],
      }).recentCompletions.single.comments;

      expect(comments.map((c) => c.text), ['первый', 'второй']);
    });

    test('ответ тренера на 2000 символов не обрезается', () {
      final text = parse({
        'recent_completions': [
          {
            'id': '1',
            'comments': [
              {'id': 'a', 'text': 'я' * 2000},
            ],
          },
        ],
      }).recentCompletions.single.comments.single.text;

      expect(text.length, 2000);
    });

    test('даты: плохая строка, null и не строка', () {
      final record = parse({
        'recent_completions': [
          {'id': '1', 'completed_at': 'когда-то'},
          {'id': '2', 'completed_at': null},
          {'id': '3', 'completed_at': 5},
        ],
      }).recentCompletions;

      expect(record.map((r) => r.completedAt), [null, null, null]);
    });

    test('записи, которые не объекты, пропускаются без утечки содержимого', () {
      final records = parse({
        'recent_completions': ['секретный текст', null, 3, {'id': 'ok'}],
      }).recentCompletions;

      expect(records.single.id, 'ok');
      expect(loggedMessages().join('\n'), contains('skipped recent_completions'));
      expect(loggedMessages().join('\n'), isNot(contains('секретный')));
    });

    test('by_program: program_id null и несколько программ', () {
      final activity = parse({
        'activity': {
          'total_completions': 5,
          'by_program': [
            {'program_id': null, 'program_name': 'Старая', 'total_completions': 3},
            {'program_id': 'p', 'program_name': 'Новая', 'program_name_ru': 'Новая ру', 'total_completions': 2},
          ],
        },
      }).activity;

      expect(activity.byProgram.map((p) => p.programName), ['Старая', 'Новая']);
      expect(activity.byProgram.map((p) => p.totalCompletions), [3, 2]);
    });

    test('30 записей разбираются целиком', () {
      final analytics = parse({
        'recent_completions': [
          for (var i = 0; i < 30; i++)
            {'id': 'c$i', 'week_number': 1, 'day_number': i + 1, 'result_text': 'r$i'},
        ],
      });

      expect(analytics.recentCompletions, hasLength(30));
      expect(analytics.recentCompletions.last.dayNumber, 30);
    });

    test('прогресс по неделям: несколько недель', () {
      final weeks = parse({
        'current_assignment': {
          'program_name': 'P',
          'progress': {
            'weeks': [
              {'week_number': 1, 'total_days': 3, 'completed_days': 3},
              {'week_number': 2, 'total_days': 4, 'completed_days': 1},
            ],
          },
        },
      }).currentAssignment!.weeks;

      expect(weeks.map((w) => w.weekNumber), [1, 2]);
      expect(weeks.map((w) => w.completedDays), [3, 1]);
    });
  });
}
