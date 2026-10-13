import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/account_deletion_state.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Причина, по которой аккаунт не удалён. Для отказов Apple — кнопка
/// «Повторить»: окно Apple откроется заново.
class AccountDeletionNotice extends StatelessWidget {
  const AccountDeletionNotice({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final AccountDeletionFailed state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: context.themeExt.destructive),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.failure.message(l10n),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (state.canRetryWithApple) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: Text(l10n.retryAction)),
          ],
        ],
      ),
    );
  }
}
