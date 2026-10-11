import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:mentorix_app/generated/assets.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Пока сессия неизвестна. Если `/auth/me` не получен из-за связи —
/// сообщение и «Повторить»: токены целы, выбрасывать на вход нельзя.
///
/// Должен выглядеть так же, как нативный экран запуска (`flutter_native_splash`),
/// иначе при смене экрана логотип «прыгает»:
/// * тот же PNG (`assets/splash`), а не SVG: `flutter_svg` рисует надпись иначе;
/// * без `SafeArea`: нативный экран центрирует логотип по всему экрану;
/// * фон и вариант логотипа — по теме; пока пользователь не выбрал свою, это
///   системная (`ThemeMode.system`), как и у нативного экрана.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Ширина логотипа в dp: PNG 960 px, как «4x» у нативного сплеша.
  static const logoWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BlocBuilder<SessionCubit, SessionState>(
            builder: (context, state) {
              final failure = state is SessionUnknown ? state.failure : null;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    isDark ? Assets.splashFullLogoDark : Assets.splashFullLogo,
                    width: logoWidth,
                    semanticLabel: l10n.appTitle,
                    filterQuality: FilterQuality.medium,
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
    );
  }
}
