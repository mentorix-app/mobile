import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Карточка тренера в списке. Пустое имя (сервер вправе его не задавать)
/// заменяется словом «Тренер». [onTap] `null` — карточка не нажимается.
class TrainerCard extends StatelessWidget {
  const TrainerCard({super.key, required this.trainer, this.onTap});

  final LinkedTrainer trainer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final name = trainer.trainerDisplayName.trim().isEmpty
        ? l10n.trainerDefaultName
        : trainer.trainerDisplayName.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.muted,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      Icons.person_outline,
                      color: tokens.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: tokens.mutedForeground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
