import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/core/widgets/brand_svg_icon.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_state.dart';
import 'package:mentorix_app/generated/assets.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<LoginCubit, LoginState>(
      listener: (context, state) => switch (state) {
        LoginFailed(:final failure) => AppSnackBar.showError(context, failure.message(l10n)),
        _ => null,
      },
      builder: (context, state) {
        final cubit = context.read<LoginCubit>();
        final busy = state is LoginInProgress;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.loginTitle, textAlign: TextAlign.center, style: textTheme.headlineLarge),
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.loginSubtitle, textAlign: TextAlign.center, style: textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.xl),
                      if (cubit.isGoogleAvailable)
                        FilledButton.icon(
                          onPressed: busy ? null : cubit.signInWithGoogle,
                          icon: const BrandSvgIcon(asset: Assets.iconsGoogle, size: 18),
                          label: Text(l10n.signInWithGoogle),
                        ),
                      if (cubit.isAppleAvailable) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: busy ? null : cubit.signInWithApple,
                          icon: const BrandSvgIcon(asset: Assets.iconsApple, size: 20, tinted: true),
                          label: Text(l10n.signInWithApple),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.loginTelegramHint,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(color: context.themeExt.mutedForeground),
                      ),
                      SizedBox(height: AppSpacing.xs, child: busy ? const LinearProgressIndicator() : null),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
