import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/account_deletion_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/account_deletion_state.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:mentorix_app/features/profile/presentation/widgets/account_deletion_notice.dart';
import 'package:mentorix_app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:mentorix_app/features/profile/presentation/widgets/profile_info_row.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Имя, почта, выход и удаление аккаунта. Кнопки стоят выше сообщения об
/// ошибке: оно появляется ниже и ничего не сдвигает.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmAndDelete(BuildContext context) async {
    final cubit = context.read<AccountDeletionCubit>();

    final confirmed = await DeleteAccountDialog.show(context);
    if (!confirmed) return;

    // Отклик не ждём: удаление не должно зависеть от платформенного канала.
    unawaited(HapticFeedback.mediumImpact());
    await cubit.delete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<AccountDeletionCubit, AccountDeletionState>(
      builder: (context, deletion) {
        final busy = deletion is AccountDeletionInProgress;

        return PopScope(
          canPop: !busy,
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.profileTitle)),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BlocBuilder<SessionCubit, SessionState>(
                          builder: (context, session) {
                            final profile = session is SessionAuthenticated
                                ? session.profile
                                : null;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProfileInfoRow(
                                  label: l10n.profileNameLabel,
                                  value: _valueOrEmpty(
                                    profile?.name,
                                    l10n.profileValueEmpty,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                ProfileInfoRow(
                                  label: l10n.profileEmailLabel,
                                  value: _valueOrEmpty(
                                    profile?.email,
                                    l10n.profileValueEmpty,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => context.read<SessionCubit>().logout(),
                          child: Text(l10n.logoutAction),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.themeExt.destructive,
                            side: BorderSide(
                              color: context.themeExt.destructive,
                            ),
                          ),
                          onPressed: busy
                              ? null
                              : () => _confirmAndDelete(context),
                          child: Text(l10n.deleteAccountAction),
                        ),
                        SizedBox(
                          height: AppSpacing.xs,
                          child: busy ? const LinearProgressIndicator() : null,
                        ),
                        if (deletion is AccountDeletionFailed) ...[
                          const SizedBox(height: AppSpacing.lg),
                          AccountDeletionNotice(
                            state: deletion,
                            onRetry: () =>
                                context.read<AccountDeletionCubit>().delete(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _valueOrEmpty(String? value, String placeholder) =>
      value == null || value.isEmpty ? placeholder : value;
}
