import 'package:flutter/material.dart';
import 'package:mentorix_app/core/widgets/adaptive_refresh_scroll_view.dart';
import 'package:mentorix_app/core/widgets/empty_state.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Тренер программу ещё не назначил (`assignment` и `program` — `null`). Это не
/// ошибка; экран обновляется свайпом вниз.
class NoProgramView extends StatelessWidget {
  const NoProgramView({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AdaptiveRefreshScrollView(
      onRefresh: onRefresh,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.fitness_center,
            title: l10n.programNotAssignedTitle,
            body: l10n.programNotAssignedBody,
          ),
        ),
      ],
    );
  }
}
