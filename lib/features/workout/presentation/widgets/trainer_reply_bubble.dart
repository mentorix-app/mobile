import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_comment.dart';
import 'package:mentorix_app/features/workout/presentation/completion_time_format.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/result_bubble.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// «Ответ тренера»: пузырь слева с рамкой, подпись, текст и время. Клиент его только
/// читает. Не шире 85%, переносы строк сохраняются.
class TrainerReplyBubble extends StatelessWidget {
  const TrainerReplyBubble({super.key, required this.comment});

  final TrainerComment comment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final textTheme = Theme.of(context).textTheme;
    final time = comment.createdAt;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * ResultBubble.maxWidthFactor,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.card,
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.statsTrainerReply,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    comment.text,
                    style: textTheme.bodyMedium?.copyWith(color: tokens.cardForeground),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      formatCompletionTime(time, l10n.localeName),
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
