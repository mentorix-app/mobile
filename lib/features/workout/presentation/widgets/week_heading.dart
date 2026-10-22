import 'package:flutter/material.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Заголовок «Неделя N» над днями, когда в программе одна неделя и выбирать
/// нечего.
class WeekHeading extends StatelessWidget {
  const WeekHeading({super.key, required this.weekNumber});

  final int weekNumber;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).weekLabel(weekNumber),
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}
