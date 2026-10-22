import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// «Выполнено»: нейтральная галочка цветом `primary` и подпись рядом, чтобы смысл
/// не держался на значке. Цвета успеха в `globals.css` нет.
class CompletedStatus extends StatelessWidget {
  const CompletedStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 18, color: context.themeExt.primary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            AppLocalizations.of(context).dayCompleted,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
