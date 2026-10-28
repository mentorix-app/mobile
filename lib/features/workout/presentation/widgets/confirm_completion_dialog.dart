import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Подтверждение перед отправкой: отметку отменить и исправить результат нельзя.
/// Показывает текст, который увидит тренер. Закрывается `true` только по кнопке
/// «Отметить»; «Назад», касание вне окна и системная кнопка — `false`.
class ConfirmCompletionDialog extends StatelessWidget {
  const ConfirmCompletionDialog({super.key, required this.text});

  /// Результат в том виде, в каком он уйдёт на сервер.
  final String text;

  static Future<bool> show(BuildContext context, {required String text}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmCompletionDialog(text: text),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;

    return AlertDialog(
      title: Text(l10n.completeConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.completeConfirmBody),
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.secondary,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryForeground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.completeBackAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.completeConfirmAction),
        ),
      ],
    );
  }
}
