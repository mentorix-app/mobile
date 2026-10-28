import 'package:flutter/material.dart';
import 'package:mentorix_app/core/widgets/pinned_action_bar.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// «Отметить выполненной» внизу экрана дня: закреплена, видна без прокрутки даже на
/// длинном дне. Открывает ввод результата; сама ничего не отправляет.
class DayCompleteBar extends StatelessWidget {
  const DayCompleteBar({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PinnedActionBar(
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          child: Text(
            AppLocalizations.of(context).dayCompleteAction,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
