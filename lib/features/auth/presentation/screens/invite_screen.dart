import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/invite_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/invite_state.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Третий шаг: ссылка или код приглашения тренера. Строка уходит на сервер
/// как есть — он принимает токен, `inv_<токен>` и ссылку целиком.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
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

    return BlocConsumer<InviteCubit, InviteState>(
      listener: (context, state) => switch (state) {
        InviteAccepted(:final acceptance) => _onAccepted(
          context,
          l10n,
          acceptance.trainerDisplayName,
        ),
        InviteSkipped() => context.go(RouteNames.home),
        InviteFailed(:final failure) => AppSnackBar.showError(
          context,
          failure.message(l10n),
        ),
        _ => null,
      },
      builder: (context, state) {
        final busy = state is InviteInProgress;

        return Scaffold(
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
                        l10n.inviteTitle,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.inviteBody,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _controller,
                        enabled: !busy,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(hintText: l10n.inviteHint),
                        onSubmitted: (_) => _submit(context),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) => FilledButton(
                          onPressed: busy || value.text.trim().isEmpty
                              ? null
                              : () => _submit(context),
                          child: Text(l10n.inviteAcceptAction),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.read<InviteCubit>().skip(),
                        child: Text(l10n.inviteSkipAction),
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
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    context.read<InviteCubit>().accept(input);
  }

  void _onAccepted(
    BuildContext context,
    AppLocalizations l10n,
    String trainerName,
  ) {
    AppSnackBar.showSuccess(
      context,
      trainerName.isEmpty
          ? l10n.inviteAcceptedNoName
          : l10n.inviteAccepted(trainerName),
    );
    context.go(RouteNames.home);
  }
}
