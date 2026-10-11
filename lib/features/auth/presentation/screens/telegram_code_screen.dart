import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_state.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Ввод 8-символьного кода от бота. Регистр и пробелы по краям серверу
/// не важны, поэтому поле их не режет.
class TelegramCodeScreen extends StatefulWidget {
  const TelegramCodeScreen({super.key});

  @override
  State<TelegramCodeScreen> createState() => _TelegramCodeScreenState();
}

class _TelegramCodeScreenState extends State<TelegramCodeScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<TelegramLinkCubit, TelegramLinkState>(
      listener: (context, state) => switch (state) {
        TelegramLinkSuccess() => context.go(RouteNames.invite),
        TelegramLinkFailed(:final failure) => AppSnackBar.showError(
          context,
          failure.message(l10n),
        ),
        _ => null,
      },
      builder: (context, state) {
        final busy = state is TelegramLinkInProgress;

        return Scaffold(
          appBar: AppBar(),
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
                        l10n.telegramCodeTitle,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _controller,
                        enabled: !busy,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: l10n.telegramCodeHint,
                        ),
                        onSubmitted: (_) => _submit(context),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) => FilledButton(
                          onPressed: busy || value.text.trim().isEmpty
                              ? null
                              : () => _submit(context),
                          child: Text(l10n.continueAction),
                        ),
                      ),
                      if (busy) ...[
                        const SizedBox(height: AppSpacing.lg),
                        const LinearProgressIndicator(),
                      ],
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

  void _submit(BuildContext context) {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    context.read<TelegramLinkCubit>().submit(code);
  }
}
