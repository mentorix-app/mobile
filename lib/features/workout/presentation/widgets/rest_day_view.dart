import 'package:flutter/material.dart';
import 'package:mentorix_app/core/widgets/adaptive_refresh_scroll_view.dart';
import 'package:mentorix_app/core/widgets/empty_state.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/day_app_bar.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Экран дня отдыха. Из списка в него попасть нельзя (карточка не нажимается), но
/// по ссылке или после обновления программы день мог оказаться пустым.
class RestDayView extends StatelessWidget {
  const RestDayView({
    super.key,
    required this.title,
    required this.trainerId,
    required this.onRefresh,
  });

  final String title;
  final String trainerId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AdaptiveRefreshScrollView(
      onRefresh: onRefresh,
      edgeOffset: LargeTitleSliverAppBar.collapsedExtent(context),
      headerSlivers: [DayAppBar(title: title, trainerId: trainerId)],
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.bedtime_outlined,
            title: l10n.dayRest,
            body: l10n.dayRestBody,
          ),
        ),
      ],
    );
  }
}
