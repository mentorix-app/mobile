import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Сообщение после ответа сервера на код: причина и подсказка «получите новый».
///
/// Для 409 дополнительно показывается текст `message` бэкенда: два случая
/// конфликта различаются только им. Это сознательное исключение из правила
/// «текст бэкенда пользователю не показывается», пока нет поля `code`.
class TelegramCodeSpentNotice extends StatelessWidget {
  const TelegramCodeSpentNotice({super.key, required this.failure});

  final AuthFailure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final backendMessage = switch (failure) {
      TelegramLinkConflictFailure(:final message) => message,
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: context.themeExt.destructive),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(failure.message(l10n), style: textTheme.bodyMedium),
          if (backendMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(backendMessage, style: textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.telegramCodeSpentHint, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
