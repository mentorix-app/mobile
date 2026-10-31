import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/features/workout/presentation/widgets/completed_status.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Конец выполненного дня: «Выполнено» и переход к результатам тренировок, где
/// виден введённый текст и ответ тренера (в ответе программы текста результата нет).
class CompletedDayFooter extends StatelessWidget {
  const CompletedDayFooter({super.key, required this.trainerId});

  final String trainerId;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CompletedStatus(),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => context.push(RouteNames.statsPath(trainerId)),
            child: Text(AppLocalizations.of(context).statsResults),
          ),
        ],
      ),
    );
  }
}
