import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_block.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/block_card.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/exercise_tile.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/expandable_text.dart';

/// Блок дня. Упражнение без группы (`single`) — обычное упражнение: без рамки блока
/// и без подписи типа; если у такого блока всё же есть инструкция, она идёт
/// примечанием под упражнением. Остальные типы — карточка [BlockCard].
class BlockView extends StatelessWidget {
  const BlockView({super.key, required this.block});

  final ProgramBlock block;

  @override
  Widget build(BuildContext context) {
    if (!block.type.isSingle) return BlockCard(block: block);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, exercise) in block.exercises.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.lg),
          ExerciseTile(
            key: ValueKey(exercise.id),
            exercise: exercise,
            blockType: block.type,
          ),
        ],
        if (block.instruction.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ExpandableText(text: block.instruction),
        ],
      ],
    );
  }
}
