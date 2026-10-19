import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/features/theme/presentation/widgets/theme_mode_button.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Каркас экранов режимов, у которых в приложении пока нет своих инструментов:
/// заголовок-пояснение и кнопки под ним.
class WebOnlyNotice extends StatelessWidget {
  const WebOnlyNotice({super.key, required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [ThemeModeButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final action in actions) ...[
                    action,
                    if (action != actions.last)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
