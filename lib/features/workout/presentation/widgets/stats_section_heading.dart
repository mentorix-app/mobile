import 'package:flutter/material.dart';

/// Заголовок раздела статистики («Текущая программа», «Результаты тренировок»).
class StatsSectionHeading extends StatelessWidget {
  const StatsSectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
