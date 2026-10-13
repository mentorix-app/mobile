import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:mentorix_app/features/theme/presentation/widgets/theme_mode_button.dart';
import 'package:mentorix_app/generated/assets.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Заглушка главного экрана: кто вошёл и переход в профиль (там выход и
/// удаление аккаунта). Заменяется настоящим экраном в следующих этапах.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: const [ThemeModeButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BlocBuilder<SessionCubit, SessionState>(
            builder: (context, state) {
              final identity = state is SessionAuthenticated
                  ? state.profile.displayName
                  : '';

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    isDark ? Assets.iconsFullLogoDark : Assets.iconsFullLogo,
                    width: 240,
                    semanticsLabel: l10n.appTitle,
                  ),
                  if (identity.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.homeSignedInAs(identity),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: () => context.push(RouteNames.profile),
                    child: Text(l10n.profileOpenAction),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
