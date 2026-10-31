import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/features/locale/presentation/cubit/locale_cubit.dart';
import 'package:mentorix_app/features/locale/presentation/widgets/language_option.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Выбор языка в профиле: «Системный / Русский / English». Русский и English
/// подписаны на своих языках всегда, «Системный» локализуется.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<LocaleCubit>();

    return BlocBuilder<LocaleCubit, Locale?>(
      builder: (context, selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileLanguageLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.themeExt.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          LanguageOption(
            label: l10n.languageSystem,
            selected: selected == null,
            onTap: () => cubit.select(null),
          ),
          LanguageOption(
            label: l10n.languageRussian,
            selected: selected?.languageCode == 'ru',
            onTap: () => cubit.select(const Locale('ru')),
          ),
          LanguageOption(
            label: l10n.languageEnglish,
            selected: selected?.languageCode == 'en',
            onTap: () => cubit.select(const Locale('en')),
          ),
        ],
      ),
    );
  }
}
