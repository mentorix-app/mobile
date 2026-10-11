import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_state.dart';
import 'package:mentorix_app/features/auth/presentation/widgets/telegram_code_spent_notice.dart';
import 'package:mentorix_app/features/auth/presentation/widgets/telegram_link_steps.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Привязка Telegram: три шага, кнопка «Открыть бота» и ввод 8-символьного кода.
/// Регистр и пробелы по краям серверу не важны, поэтому поле их не режет.
///
/// Код одноразовый: после ответа сервера на него (кроме 429 и 401) поле
/// очищается и показывается подсказка получить новый код в боте.
///
/// Раскладка прижата к верху, а не центрирована, и всё динамическое
/// (индикатор, сообщение об ошибке) лежит **ниже** поля и кнопок: клавиатура,
/// загрузка и сообщения не двигают то, во что целится палец.
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
        TelegramLinkFailed(:final failure, :final codeSpent) => _onFailed(
          context,
          l10n,
          failure,
          codeSpent,
        ),
        _ => null,
      },
      builder: (context, state) {
        final cubit = context.read<TelegramLinkCubit>();
        final busy = state is TelegramLinkInProgress;
        final spentFailure = state is TelegramLinkFailed && state.codeSpent
            ? state.failure
            : null;

        return Scaffold(
          appBar: AppBar(),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.telegramCodeTitle,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const TelegramLinkSteps(),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        // Имя бота — из config/stage.json; пока плейсхолдер,
                        // кнопка неактивна.
                        onPressed: cubit.isBotConfigured && !busy
                            ? () => _openBot(context, l10n)
                            : null,
                        icon: const FaIcon(FontAwesomeIcons.telegram, size: 20),
                        label: Text(l10n.telegramOpenBotAction),
                      ),
                      const SizedBox(height: AppSpacing.xl),
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
                      // Место под индикатор есть всегда, иначе загрузка
                      // сдвигала бы всё, что ниже.
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: AppSpacing.xs,
                        child: busy ? const LinearProgressIndicator() : null,
                      ),
                      if (spentFailure != null)
                        // Только пока поле пустое: когда вводят новый код,
                        // сообщение про старый не нужно. Оно в самом низу,
                        // поэтому его появление и исчезновение ничего выше
                        // не двигает.
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) => value.text.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.lg,
                                  ),
                                  child: TelegramCodeSpentNotice(
                                    failure: spentFailure,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
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

  Future<void> _openBot(BuildContext context, AppLocalizations l10n) async {
    final opened = await context.read<TelegramLinkCubit>().openBot();
    if (opened || !context.mounted) return;
    AppSnackBar.showError(context, l10n.errorOpenTelegram);
  }

  /// Код потрачен — поле очищается, причину и подсказку показывает экран.
  /// Код ещё действует (429, 401, нет связи) — поле остаётся, ошибка в снекбаре.
  void _onFailed(
    BuildContext context,
    AppLocalizations l10n,
    AuthFailure failure,
    bool codeSpent,
  ) {
    if (codeSpent) {
      _controller.clear();
      return;
    }
    AppSnackBar.showError(context, failure.message(l10n));
  }
}
