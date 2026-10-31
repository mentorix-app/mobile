import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/core/widgets/option_row.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Выбор темы в настройках: «Системная / Светлая / Тёмная».
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ThemeCubit>();

    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsThemeLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.themeExt.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OptionRow(
            label: l10n.themeOptionSystem,
            selected: selected == ThemeMode.system,
            onTap: () => cubit.setThemeMode(ThemeMode.system),
          ),
          OptionRow(
            label: l10n.themeOptionLight,
            selected: selected == ThemeMode.light,
            onTap: () => cubit.setThemeMode(ThemeMode.light),
          ),
          OptionRow(
            label: l10n.themeOptionDark,
            selected: selected == ThemeMode.dark,
            onTap: () => cubit.setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}
