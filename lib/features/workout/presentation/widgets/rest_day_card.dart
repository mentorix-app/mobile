import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// День отдыха (день без блоков): тихая строка — без заливки, только тонкая
/// граница, одна строка текста приглушённым цветом, ниже тренировочной карточки.
/// Не нажимается: отметить такой день нельзя (сервер ответил бы 404
/// `day_not_found`).
class RestDayCard extends StatelessWidget {
  const RestDayCard({super.key, required this.dayNumber});

  final int dayNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            '${l10n.dayLabel(dayNumber)} · ${l10n.dayRest}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.themeExt.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
