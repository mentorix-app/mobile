import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Подтверждение удаления аккаунта: что именно пропадёт и что восстановить
/// нельзя. Закрывается `true` только по кнопке «Удалить навсегда».
class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.deleteAccountDialogTitle),
      content: Text(l10n.deleteAccountDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelAction),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.themeExt.destructive,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.deleteAccountConfirmAction),
        ),
      ],
    );
  }
}
