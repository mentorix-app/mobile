import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        final (icon, label) = switch (mode) {
          ThemeMode.system => (Icons.brightness_auto_outlined, l10n.themeModeSystem),
          ThemeMode.light => (Icons.light_mode_outlined, l10n.themeModeLight),
          ThemeMode.dark => (Icons.dark_mode_outlined, l10n.themeModeDark),
        };

        return IconButton(
          icon: Icon(icon),
          tooltip: label,
          onPressed: () => context.read<ThemeCubit>().setThemeMode(switch (mode) {
            ThemeMode.system => ThemeMode.light,
            ThemeMode.light => ThemeMode.dark,
            ThemeMode.dark => ThemeMode.system,
          }),
        );
      },
    );
  }
}
