import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/workout/domain/entities/completion_record.dart';
import 'package:mentorix_app/features/workout/presentation/completion_time_format.dart';
import 'package:mentorix_app/features/workout/presentation/localized_name.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/result_bubble.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/trainer_reply_bubble.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Одна отметка в истории: «Неделя N, день M» и время, пузырь с результатом клиента,
/// под ним ответ тренера (если есть). Неделя, день и название программы — снимок на
/// момент отметки. Пустой результат пузырь не рисует. Бейджа «Текущий цикл» нет.
class CompletionTile extends StatelessWidget {
  const CompletionTile({
    super.key,
    required this.record,
    this.showProgramName = false,
  });

  final CompletionRecord record;

  /// Подпись программы под заголовком; нужна, когда программ было несколько.
  final bool showProgramName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final textTheme = Theme.of(context).textTheme;
    final time = record.completedAt;
    final program = localizedName(
      name: record.programName,
      nameRu: record.programNameRu,
      localeName: l10n.localeName,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.workoutDayTitle(record.weekNumber, record.dayNumber),
          style: textTheme.titleMedium,
        ),
        if (time != null)
          Text(
            formatCompletionTime(time, l10n.localeName),
            style: textTheme.bodySmall?.copyWith(color: tokens.mutedForeground),
          ),
        if (showProgramName && program.isNotEmpty)
          Text(
            program,
            style: textTheme.bodySmall?.copyWith(color: tokens.mutedForeground),
          ),
        if (record.resultText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ResultBubble(text: record.resultText),
        ],
        for (final comment in record.comments) ...[
          const SizedBox(height: AppSpacing.sm),
          TrainerReplyBubble(key: ValueKey(comment.id), comment: comment),
        ],
      ],
    );
  }
}
