import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Ошибка на всю страницу: значок, локализованное сообщение и «Повторить».
/// [onRetry] `null` — кнопки нет (повторять нечего, например связи с тренером
/// больше нет). Лежит в `CustomScrollView`, чтобы помещаться при большом шрифте.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: context.themeExt.mutedForeground,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(l10n.retryAction),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
