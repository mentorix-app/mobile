import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:mentorix_app/generated/assets.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Пока сессия неизвестна. Если `/auth/me` не получен из-за связи —
/// сообщение и «Повторить»: токены целы, выбрасывать на вход нельзя.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: BlocBuilder<SessionCubit, SessionState>(
              builder: (context, state) {
                final failure = state is SessionUnknown ? state.failure : null;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      isDark ? Assets.iconsFullLogoDark : Assets.iconsFullLogo,
                      width: 240,
                      semanticsLabel: l10n.appTitle,
                    ),
                    if (failure != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        failure.message(l10n),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: () => context.read<SessionCubit>().start(),
                        child: Text(l10n.retryAction),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
