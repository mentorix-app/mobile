import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Пояснение внутри экрана (не уведомление): значок и текст в тонкой рамке.
/// Остаётся на месте, пока причина не ушла, — в отличие от snackbar.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeExt;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: tokens.mutedForeground),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
