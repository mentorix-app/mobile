import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_comment.dart';

/// Запись об отметке в статистике. Неделя, день и название программы — снимок на
/// момент отметки, а не текущие значения программы.
class CompletionRecord extends Equatable {
  const CompletionRecord({
    required this.id,
    this.completedAt,
    this.programName = '',
    this.programNameRu = '',
    this.weekNumber = 0,
    this.dayNumber = 0,
    this.resultText = '',
    this.comments = const [],
  });

  final String id;

  /// UTC; на экране показывается в часовом поясе устройства.
  final DateTime? completedAt;
  final String programName;
  final String programNameRu;
  final int weekNumber;
  final int dayNumber;

  /// Текст клиента; из Telegram мог прийти без проверок, поэтому очищен от
  /// запрещённых управляющих символов.
  final String resultText;

  /// Ответы тренера, старые первыми.
  final List<TrainerComment> comments;

  @override
  List<Object?> get props => [
    id,
    completedAt,
    programName,
    programNameRu,
    weekNumber,
    dayNumber,
    resultText,
    comments,
  ];
}
