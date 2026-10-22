import 'package:flutter/material.dart';
import 'package:mentorix_app/core/widgets/adaptive_refresh_scroll_view.dart';
import 'package:mentorix_app/core/widgets/empty_state.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Тренера нет: пояснение и переход к приглашению. Лежит в области с
/// pull-to-refresh, чтобы список можно было обновить, не выходя с экрана.
class NoTrainerView extends StatelessWidget {
  const NoTrainerView({
    super.key,
    required this.onRefresh,
    required this.onEnterInvite,
  });

  final Future<void> Function() onRefresh;
  final VoidCallback onEnterInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AdaptiveRefreshScrollView(
      onRefresh: onRefresh,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.groups_outlined,
            title: l10n.trainersEmptyTitle,
            body: l10n.trainersEmptyBody,
            actionLabel: l10n.trainersEmptyAction,
            onAction: onEnterInvite,
          ),
        ),
      ],
    );
  }
}
