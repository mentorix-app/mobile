import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:mentorix_app/core/widgets/app_back_button.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/core/widgets/notice_banner.dart';
import 'package:mentorix_app/core/widgets/pinned_action_bar.dart';
import 'package:mentorix_app/features/workout/domain/workout_text.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/completion_cubit.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/completion_state.dart';
import 'package:mentorix_app/features/workout/presentation/max_code_points_formatter.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/confirm_completion_dialog.dart';
import 'package:mentorix_app/features/workout/presentation/workout_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Ввод результата и отправка. Отметку отменить нельзя, поэтому «Далее» открывает
/// подтверждение с текстом, и запрос уходит только после него.
///
/// Текст хранит этот экран, а не кубит: после `program_changed` и других ошибок
/// поле остаётся как было. Кнопка внизу закреплена и поднимается над клавиатурой;
/// пока идёт отправка, поле, кнопка и «назад» заблокированы.
class CompleteDayForm extends StatefulWidget {
  const CompleteDayForm({
    super.key,
    required this.trainerId,
    required this.dayKey,
    required this.dayTitle,
  });

  final String trainerId;
  final String dayKey;

  /// «Неделя N, день M».
  final String dayTitle;

  @override
  State<CompleteDayForm> createState() => _CompleteDayFormState();
}

class _CompleteDayFormState extends State<CompleteDayForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSubmit(BuildContext context) async {
    final cubit = context.read<CompletionCubit>();
    final text = WorkoutText.prepareResult(_controller.text);

    final confirmed = await ConfirmCompletionDialog.show(context, text: text);
    if (!confirmed || !mounted) return;

    await cubit.submit(text);
  }

  void _onDone(BuildContext context, AppLocalizations l10n, bool refreshFailed) {
    // Отклик не ждём: отметка не должна зависеть от платформенного канала.
    unawaited(HapticFeedback.mediumImpact());
    refreshFailed
        ? AppSnackBar.showWarning(context, l10n.completeSavedRefreshFailed)
        : AppSnackBar.showSuccess(context, l10n.completeSavedMessage);
    context.pop();
  }

  void _onClosed(
    BuildContext context,
    AppLocalizations l10n,
    CompletionCloseReason reason,
  ) {
    AppSnackBar.showInfo(
      context,
      switch (reason) {
        CompletionCloseReason.alreadyCompleted =>
          l10n.errorWorkoutAlreadyCompleted,
        CompletionCloseReason.dayGone => l10n.errorWorkoutDayNotFound,
        CompletionCloseReason.notAssigned => l10n.programNotAssignedTitle,
      },
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.themeExt;
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<CompletionCubit, CompletionState>(
      listener: (context, state) => switch (state) {
        CompletionFailed(:final failure) => AppSnackBar.showError(
          context,
          failure.message(l10n),
        ),
        CompletionDone(:final refreshFailed) => _onDone(
          context,
          l10n,
          refreshFailed,
        ),
        CompletionClosed(:final reason) => _onClosed(context, l10n, reason),
        _ => null,
      },
      builder: (context, state) {
        final busy = state is CompletionSubmitting;
        final programChanged = state is CompletionIdle && state.programChanged;

        return PopScope(
          canPop: !busy,
          child: Scaffold(
            body: SafeArea(
              // Нижний отступ берёт на себя закреплённая панель.
              top: false,
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  LargeTitleSliverAppBar(
                    title: l10n.completeTitle,
                    leading: AppBackButton(
                      fallbackLocation: RouteNames.workoutDayPath(
                        widget.trainerId,
                        widget.dayKey,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    sliver: SliverList.list(
                      children: [
                        Text(
                          widget.dayTitle,
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(l10n.completeHint, style: textTheme.bodyMedium),
                        if (programChanged) ...[
                          const SizedBox(height: AppSpacing.lg),
                          NoticeBanner(message: l10n.errorWorkoutProgramChanged),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          controller: _controller,
                          enabled: !busy,
                          minLines: 5,
                          maxLines: 10,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: const [
                            MaxCodePointsFormatter(WorkoutText.maxResultLength),
                          ],
                          decoration: InputDecoration(
                            hintText: l10n.completeFieldHint,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) => Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              l10n.completeCounter(
                                WorkoutText.characterCount(value.text),
                                WorkoutText.maxResultLength,
                              ),
                              style: textTheme.bodySmall?.copyWith(
                                color: tokens.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Закреплена внизу: тело кончается над ней, уведомления об ошибках
            // встают над ней, а не перекрывают кнопку; клавиатура её поднимает.
            bottomNavigationBar: PinnedActionBar(
              child: SizedBox(
                width: double.infinity,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => FilledButton(
                    onPressed:
                        busy ||
                            !WorkoutText.isValidResult(
                              WorkoutText.prepareResult(value.text),
                            )
                        ? null
                        : () => _confirmAndSubmit(context),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.completeNextAction),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
