import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';
import 'package:mentorix_app/features/mode/presentation/cubit/dashboard_link_cubit.dart';
import 'package:mentorix_app/features/mode/presentation/cubit/dashboard_link_state.dart';
import 'package:mentorix_app/features/mode/presentation/widgets/web_only_notice.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Режим «только тренер»: нативных инструментов пока нет, работа — в
/// веб-кабинете. Профиль (выход, удаление аккаунта) доступен с этого экрана.
class TrainerWebOnlyScreen extends StatelessWidget {
  const TrainerWebOnlyScreen({super.key});

  Future<void> _openDashboard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final opened = await context.read<DashboardLinkCubit>().openDashboard();
    if (opened || !context.mounted) return;
    AppSnackBar.showError(context, l10n.errorOpenDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DashboardLinkCubit>();

    return BlocBuilder<DashboardLinkCubit, DashboardLinkState>(
      builder: (context, state) => WebOnlyNotice(
        title: l10n.trainerWebOnlyTitle,
        actions: [
          FilledButton(
            // Адрес — из config/stage.json; пока плейсхолдер, кнопка неактивна.
            onPressed: cubit.isConfigured && state is! DashboardLinkOpening
                ? () => _openDashboard(context)
                : null,
            child: Text(l10n.trainerOpenDashboardAction),
          ),
          OutlinedButton(
            onPressed: () => context.push(RouteNames.profile),
            child: Text(l10n.profileOpenAction),
          ),
        ],
      ),
    );
  }
}
