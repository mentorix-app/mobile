import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/mode/presentation/widgets/web_only_notice.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Режим «администратор»: администрирование только в веб-кабинете. Выйти можно
/// сразу; в профиле — то же самое и попытка удаления (сервер ответит 409).
class AdminWebOnlyScreen extends StatelessWidget {
  const AdminWebOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return WebOnlyNotice(
      title: l10n.adminWebOnlyTitle,
      actions: [
        FilledButton(
          onPressed: () => context.read<SessionCubit>().logout(),
          child: Text(l10n.logoutAction),
        ),
        OutlinedButton(
          onPressed: () => context.push(RouteNames.profile),
          child: Text(l10n.profileOpenAction),
        ),
      ],
    );
  }
}
