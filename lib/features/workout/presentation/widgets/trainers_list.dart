import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/adaptive_refresh_scroll_view.dart';
import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/trainer_card.dart';

/// Список тренеров с pull-to-refresh. Карточки с ключом по `trainer_id`: порядок
/// и состав меняются при обновлении.
class TrainersList extends StatelessWidget {
  const TrainersList({
    super.key,
    required this.trainers,
    required this.onRefresh,
    this.onTrainerTap,
  });

  final List<LinkedTrainer> trainers;
  final Future<void> Function() onRefresh;
  final ValueChanged<LinkedTrainer>? onTrainerTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveRefreshScrollView(
      onRefresh: onRefresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: trainers.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final trainer = trainers[index];

              return TrainerCard(
                key: ValueKey(trainer.trainerId),
                trainer: trainer,
                onTap: onTrainerTap == null
                    ? null
                    : () => onTrainerTap!(trainer),
              );
            },
          ),
        ),
      ],
    );
  }
}
