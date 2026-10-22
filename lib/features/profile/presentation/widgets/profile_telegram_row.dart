import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Строка «Telegram» в профиле. Привязан — «Привязан» без кнопки (отвязки на
/// сервере нет). Не привязан — «Не привязан» и «Привязать»: [onLink] открывает тот
/// же ввод кода, что и онбординг.
class ProfileTelegramRow extends StatelessWidget {
  const ProfileTelegramRow({super.key, required this.linked, this.onLink});

  final bool linked;

  /// Нажатие на «Привязать»; `null` — кнопка неактивна (идёт удаление аккаунта).
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final textTheme = Theme.of(context).textTheme;

    // Wrap, а не Row: на узком экране с крупным шрифтом кнопка уходит на
    // следующую строку, а не вылезает за край.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileTelegramLabel,
                style: textTheme.bodySmall?.copyWith(color: tokens.mutedForeground),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                linked ? l10n.profileTelegramLinked : l10n.profileTelegramNotLinked,
                style: textTheme.bodyLarge,
              ),
            ],
          ),
          if (!linked)
            OutlinedButton(
              onPressed: onLink,
              child: Text(l10n.profileTelegramLinkAction),
            ),
        ],
      ),
    );
  }
}
