import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_state.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Второй шаг после входа: «Вы уже занимаетесь через Telegram?».
/// Раньше приглашения — иначе привязать Telegram будет нельзя (409).
class TelegramOfferScreen extends StatelessWidget {
  const TelegramOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocListener<TelegramLinkCubit, TelegramLinkState>(
      listener: (context, state) => switch (state) {
        TelegramLinkSkipped() => context.go(RouteNames.invite),
        _ => null,
      },
      child: Scaffold(
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
                    Text(
                      l10n.telegramOfferTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.telegramOfferBody,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: () => context.push(RouteNames.telegramCode),
                      icon: const FaIcon(FontAwesomeIcons.telegram, size: 20),
                      label: Text(l10n.telegramLinkAction),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () =>
                          context.read<TelegramLinkCubit>().skip(),
                      child: Text(l10n.telegramSkipAction),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
