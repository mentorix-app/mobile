import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Три шага привязки Telegram: открыть бота, получить код, ввести его.
class TelegramLinkSteps extends StatelessWidget {
  const TelegramLinkSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final steps = [l10n.telegramStep1, l10n.telegramStep2, l10n.telegramStep3];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSpacing.xl,
                  child: Text('${index + 1}.', style: textTheme.bodyMedium),
                ),
                Expanded(child: Text(step, style: textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
