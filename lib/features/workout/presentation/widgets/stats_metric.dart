import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Одно число активности с подписью («Всего» — 12).
class StatsMetric extends StatelessWidget {
  const StatsMetric({super.key, required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: context.themeExt.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('$value', style: textTheme.headlineSmall),
      ],
    );
  }
}
