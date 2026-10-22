import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_block.dart';
import 'package:mentorix_app/features/workout/presentation/block_type_label.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/exercise_tile.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/expandable_text.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Групповой блок (суперсет, EMOM, AMRAP, …): карточка с подписью типа,
/// инструкцией блока и упражнениями. Упражнения без группы (`single`) сюда не
/// попадают — они рисуются просто упражнением (`BlockView`).
class BlockCard extends StatelessWidget {
  const BlockCard({super.key, required this.block});

  final ProgramBlock block;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              block.type.label(l10n),
              style: textTheme.titleLarge?.copyWith(color: tokens.mutedForeground),
            ),
            if (block.instruction.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ExpandableText(text: block.instruction),
            ],
            for (final exercise in block.exercises) ...[
              const SizedBox(height: AppSpacing.lg),
              Divider(height: 1, color: tokens.border),
              const SizedBox(height: AppSpacing.lg),
              ExerciseTile(
                key: ValueKey(exercise.id),
                exercise: exercise,
                blockType: block.type,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
