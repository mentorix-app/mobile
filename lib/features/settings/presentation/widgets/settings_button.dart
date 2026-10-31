import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Значок «Настройки» в шапке главного экрана и экранов тренера и администратора.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: AppLocalizations.of(context).settingsOpenAction,
      onPressed: () => context.push(RouteNames.settings),
    );
  }
}
